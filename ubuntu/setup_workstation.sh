#!/usr/bin/env bash
# ==============================================================================
# setup_workstation.sh - Inicialización modular de entorno Ubuntu
# ==============================================================================
set -euo pipefail

log_info()    { echo -e "\e[34m[INFO]\e[0m $*"; }
log_success() { echo -e "\e[32m[OK]\e[0m $*"; }
log_warn()    { echo -e "\e[33m[WARN]\e[0m $*"; }
log_error()   { echo -e "\e[31m[ERROR]\e[0m $*" >&2; }

if [[ $EUID -ne 0 ]]; then
    log_error "Este script debe ejecutarse con sudo: sudo $0"
    exit 1
fi

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

export DEBIAN_FRONTEND=noninteractive

STATE_FILE="/etc/workstation.state"

# Carga variables persistidas si el script se vuelve a ejecutar
if [[ -f "$STATE_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$STATE_FILE"
fi

# ------------------------------------------------------------------------------
# Bloque 1: Detección e instalación de drivers de NVidia
# ------------------------------------------------------------------------------
check_gpu_and_ollama_preference() {
    log_info "Verificando prerrequisitos de hardware para Ollama..."

    # Si ya se tomó una decisión en una ejecución previa, se respeta
    if [[ -n "${OLLAMA_ENABLED:-}" ]]; then
        log_info "Preferencia previa encontrada: OLLAMA_ENABLED=$OLLAMA_ENABLED"
        return 0
    fi

    # 1. Detección de presencia física de GPU NVIDIA
    if ! lspci | grep -qi "nvidia"; then
        log_warn "No se detectó GPU NVIDIA dedicada en este equipo."
        log_info "Ollama se omitirá. Se continuará con el setup base y DevContainers."
        echo "OLLAMA_ENABLED=false" >> "$STATE_FILE"
        export OLLAMA_ENABLED=false
        return 0
    fi

    # 2. Comprobar si el driver privativo ya está activo
    if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
        log_success "GPU NVIDIA detectada y controladores funcionando correctamente."
        echo "OLLAMA_ENABLED=true" >> "$STATE_FILE"
        export OLLAMA_ENABLED=true
        return 0
    fi

    # 3. Hardware presente pero sin controladores privativos activos
    log_warn "Se detectó una GPU NVIDIA, pero los controladores oficiales no están activos (ej. nouveau en uso)."
    echo ""
    echo "Para que Ollama funcione con aceleración por hardware es necesario instalar los drivers privativos y reiniciar."
    
    # Leer directamente de /dev/tty para funcionar dentro de 'wget | bash'
    local choice
    read -rp "¿Deseas instalar los controladores privativos recomendados ahora? [s/N]: " choice </dev/tty
    echo ""

    case "$choice" in
        [sS][iI]|[sS])
            log_info "Instalando controladores recomendados mediante ubuntu-drivers..."
            ubuntu-drivers install
            log_warn "Los controladores han sido instalados. Es obligatorio reiniciar el sistema."
            log_warn "Por favor, ejecuta: sudo reboot"
            log_warn "Al reiniciar, vuelve a ejecutar este script para continuar con el Bloque 1 y Docker."
            exit 0
            ;;
        *)
            log_info "Instalación de drivers omitida por el usuario."
            log_info "Se continuará el aprovisionamiento omitiendo Ollama."
            echo "OLLAMA_ENABLED=false" >> "$STATE_FILE"
            export OLLAMA_ENABLED=false
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Bloque 2: Herramientas del Sistema, CLI, Prerrequisitos y Red
# ------------------------------------------------------------------------------
install_system_core() {
    log_info "Actualizando repositorios APT..."
    apt-get update -y

    # Prerrequisitos críticos (git, curl) van primero
    local pkgs=(
        # Control de versiones y descarga
        git curl
        # Shells y multiplexores
        zsh tmux
        # Monitoreo e inspección
        btop fastfetch iotop sysstat
        # Manipulación y navegación de archivos
        tree eza bat fzf ripgrep fd-find
        # Red y diagnóstico
        net-tools iproute2 nmap traceroute mtr dnsutils tcpdump iperf3
        # Compresión y utilidades base
        unzip p7zip-full jq openssl ca-certificates gnupg software-properties-common
    )

    log_info "Instalando paquetes base y dependencias CLI..."
    apt-get install -y --no-install-recommends "${pkgs[@]}"

    # Enlaces simbólicos de compatibilidad para Ubuntu
    if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
        ln -sf "$(command -v batcat)" /usr/local/bin/bat
        log_success "Alias binario creado: bat -> batcat"
    fi

    if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
        ln -sf "$(command -v fdfind)" /usr/local/bin/fd
        log_success "Alias binario creado: fd -> fdfind"
    fi

    # Starship Prompt
    if ! command -v starship &>/dev/null; then
        log_info "Instalando Starship prompt..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y >/dev/null
        log_success "Starship instalado."
    else
        log_info "Starship ya está instalado. Omitiendo..."
    fi

    # Oh My Zsh (Requiere git y curl ya instalados)
    if [[ ! -d "$TARGET_HOME/.oh-my-zsh" ]]; then
        log_info "Instalando Oh My Zsh para $TARGET_USER..."
        local omz_installer="/tmp/install_omz.sh"
        curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$omz_installer"
        sudo -u "$TARGET_USER" sh "$omz_installer" --unattended
        rm -f "$omz_installer"

        if ! grep -q 'starship init zsh' "$TARGET_HOME/.zshrc" 2>/dev/null; then
            echo 'eval "$(starship init zsh)"' >> "$TARGET_HOME/.zshrc"
            chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.zshrc"
        fi
        log_success "Oh My Zsh y Starship configurados para $TARGET_USER."
    else
        log_info "Oh My Zsh ya está presente. Omitiendo..."
    fi

    # Configurar Zsh como shell predeterminado
    local current_shell
    current_shell=$(getent passwd "$TARGET_USER" | cut -d: -f7)
    local zsh_path
    zsh_path=$(command -v zsh)

    if [[ "$current_shell" != "$zsh_path" ]]; then
        log_info "Cambiando shell por defecto de $TARGET_USER a Zsh..."
        chsh -s "$zsh_path" "$TARGET_USER"
        log_success "Shell predeterminado actualizado a Zsh."
    fi

    log_success "Bloque 1 completado con éxito."
}

# ------------------------------------------------------------------------------
# Bloque 3: Docker
# ------------------------------------------------------------------------------
install_docker_engine() {
    if command -v docker &>/dev/null; then
        log_info "Docker Engine ya está instalado. Omitiendo..."
    else
        log_info "Configurando repositorio oficial de Docker..."
        install -m 0755 -d /etc/apt/keyrings

        # Descarga de clave GPG de Docker
        if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
            chmod a+r /etc/apt/keyrings/docker.asc
        fi

        # Agregar repositorio oficial firmado por la clave
        local arch codename
        arch=$(dpkg --print-architecture)
        codename=$(. /etc/os-release && echo "$VERSION_CODENAME")

        echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${codename} stable" \
            > /etc/apt/sources.list.d/docker.list

        apt-get update -y
        log_info "Instalando Docker Engine, CLI, Containerd y Plugins..."
        apt-get install -y --no-install-recommends \
            docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        log_success "Docker Engine instalado correctamente."
    fi

    # Configuración de permisos sin sudo para el usuario
    if ! id -nG "$TARGET_USER" | grep -qw "docker"; then
        log_info "Añadiendo a $TARGET_USER al grupo 'docker'..."
        usermod -aG docker "$TARGET_USER"
        log_success "Usuario $TARGET_USER añadido al grupo docker."
    else
        log_info "El usuario $TARGET_USER ya pertenece al grupo docker."
    fi

    # Habilitar y verificar el servicio
    systemctl enable docker.service
    systemctl start docker.service
    log_success "Servicio Docker activo y habilitado."
}

# ------------------------------------------------------------------------------
# Bloque 4: Instala NVidia Docker Toolkit 
# ------------------------------------------------------------------------------
install_nvidia_docker_toolkit() {
    if [[ "${OLLAMA_ENABLED:-false}" != "true" ]]; then
        log_info "GPU NVIDIA no habilitada. Omitiendo NVIDIA Container Toolkit..."
        return 0
    fi

    if dpkg -l | grep -qw "nvidia-container-toolkit"; then
        log_info "NVIDIA Container Toolkit ya está instalado. Omitiendo..."
    else
        log_info "Configurando repositorio oficial de NVIDIA Container Toolkit..."
        
        # 1. Limpiar archivos corruptos o mal formateados previos
        rm -f /etc/apt/keyrings/nvidia-container-toolkit.asc
        rm -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
        rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list

        # 2. Descargar y desarmar la clave en .gpg binario válido
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
            | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
        chmod a+r /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

        # 3. Configurar la lista apuntando explícitamente a la llave .gpg
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
            | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
            > /etc/apt/sources.list.d/nvidia-container-toolkit.list

        apt-get update -y
        log_info "Instalando nvidia-container-toolkit..."
        apt-get install -y --no-install-recommends nvidia-container-toolkit

        # 4. Registrar el runtime en Docker y reiniciar el servicio
        log_info "Configurando runtime de Docker para NVIDIA..."
        nvidia-ctk runtime configure --runtime=docker
        systemctl restart docker

        log_success "NVIDIA Container Toolkit instalado y Docker configurado con GPU."
    fi
}

main() {
    log_info "Iniciando aprovisionamiento del entorno..."
    
    # 1. Prerrequisito crítico: chequeo de hardware/drivers antes de tocar paquetes
    check_gpu_and_ollama_preference

    # 2. Setup base del sistema
    install_system_core

    # 3. Setup base del sistema
    install_docker_engine

    # 4. Instala NVidia Docker Toolkit
    install_nvidia_docker_toolkit

    log_success "Fase inicial completada con éxito."
}

main "$@"
