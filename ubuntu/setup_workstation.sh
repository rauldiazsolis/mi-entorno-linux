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

# ------------------------------------------------------------------------------
# Bloque 1: Herramientas del Sistema, CLI, Prerrequisitos y Red
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

main() {
    log_info "Iniciando aprovisionamiento del entorno..."
    install_system_core
    log_success "Aprovisionamiento base finalizado."
}

main "$@"
