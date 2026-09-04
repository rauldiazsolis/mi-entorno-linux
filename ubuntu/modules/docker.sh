#!/usr/bin/env bash
# ==============================================================================
# docker.sh - Motor Docker oficial y aceleración GPU (Container Toolkit)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=../common.sh
source "${SCRIPT_DIR}/../common.sh"

check_root
load_state

ACTION="${1:-install}"

install_docker() {
    log_info "Verificando prerrequisitos para Docker..."
    require_state "MODULE_CORE" "installed" "core.sh"
    require_state "GPU_DECIDED" "true" "gpu.sh"

    # 1. Instalación de Docker Engine oficial
    if command -v docker &>/dev/null; then
        log_info "Docker Engine ya está instalado. Omitiendo..."
    else
        log_info "Configurando repositorio oficial de Docker..."
        install -m 0755 -d /etc/apt/keyrings

        if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
            chmod a+r /etc/apt/keyrings/docker.asc
        fi

        local arch codename
        arch=$(dpkg --print-architecture)
        codename=$(. /etc/os-release && echo "$VERSION_CODENAME")

        echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${codename} stable" \
            > /etc/apt/sources.list.d/docker.list

        apt-get update -y
        log_info "Instalando paquetes de Docker Engine..."
        apt-get install -y --no-install-recommends \
            docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        log_success "Docker Engine instalado correctamente."
    fi

    # 2. Permisos sin sudo para el usuario final
    if ! id -nG "$TARGET_USER" | grep -qw "docker"; then
        log_info "Añadiendo a $TARGET_USER al grupo 'docker'..."
        usermod -aG docker "$TARGET_USER"
        log_success "Usuario $TARGET_USER agregado al grupo docker."
    fi

    systemctl enable docker.service
    systemctl start docker.service

    # 3. Soporte de GPU (solo si el módulo GPU habilitó aceleración)
    if [[ "${GPU_DRIVER_INSTALLED:-false}" == "true" ]]; then
        if dpkg -l | grep -qw "nvidia-container-toolkit"; then
            log_info "NVIDIA Container Toolkit ya está presente. Omitiendo..."
        else
            log_info "Configurando repositorio de NVIDIA Container Toolkit..."
            install -m 0755 -d /etc/apt/keyrings

            curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
                -o /etc/apt/keyrings/nvidia-container-toolkit.asc
            chmod 644 /etc/apt/keyrings/nvidia-container-toolkit.asc

            curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
                | sed 's#deb https://#deb [signed-by=/etc/apt/keyrings/nvidia-container-toolkit.asc] https://#g' \
                > /etc/apt/sources.list.d/nvidia-container-toolkit.list

            apt-get update -y
            log_info "Instalando nvidia-container-toolkit..."
            apt-get install -y --no-install-recommends nvidia-container-toolkit

            nvidia-ctk runtime configure --runtime=docker
            systemctl restart docker
            log_success "NVIDIA Container Toolkit configurado con éxito."
        fi
    else
        log_info "Aceleración NVIDIA desactivada en gpu.sh. Omitiendo Container Toolkit."
    fi

    set_state_var "MODULE_DOCKER" "installed"
    log_success "Módulo Docker completado y registrado."
}

remove_docker() {
    log_info "Solicitada desinstalación del módulo Docker..."

    # Bloqueo inverso si módulos superiores dependen de Docker
    prevent_removal_if "MODULE_ANTIGRAVITY" "antigravity.sh"

    log_info "Deteniendo servicios de Docker..."
    systemctl stop docker.service docker.socket 2>/dev/null || true

    local pkgs_to_remove=(
        nvidia-container-toolkit libnvidia-container-tools libnvidia-container1
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    )

    log_info "Eliminando paquetes de Docker y GPU Toolkit..."
    apt-get remove -y "${pkgs_to_remove[@]}" || true

    # Limpieza de repositorios y claves
    rm -f /etc/apt/sources.list.d/docker.list
    rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list
    rm -f /etc/apt/keyrings/docker.asc
    rm -f /etc/apt/keyrings/nvidia-container-toolkit.asc
    rm -f /etc/docker/daemon.json

    unset_state_var "MODULE_DOCKER"
    log_success "Módulo Docker desinstalado y desregistrado con éxito."
}

case "$ACTION" in
    install)          install_docker ;;
    remove|uninstall) remove_docker ;;
    *)
        log_error "Acción no válida: '$ACTION'. Usa 'install' o 'remove'."
        exit 1
        ;;
esac
