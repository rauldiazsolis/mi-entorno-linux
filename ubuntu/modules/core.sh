#!/usr/bin/env bash
# ==============================================================================
# core.sh - Paquetes base, shells, herramientas CLI y red
# ==============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=../common.sh
source "${SCRIPT_DIR}/../common.sh"

check_root
load_state

ACTION="${1:-install}"

install_core() {
    log_info "Iniciando instalación de herramientas Core del sistema..."

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y

    local pkgs=(
        git curl zsh tmux
        btop fastfetch iotop sysstat
        tree eza bat fzf ripgrep fd-find
        net-tools iproute2 nmap traceroute mtr dnsutils tcpdump iperf3
        unzip p7zip-full jq openssl ca-certificates gnupg software-properties-common
    )

    apt-get install -y --no-install-recommends "${pkgs[@]}"

    # Aliases binarios
    if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
        ln -sf "$(command -v batcat)" /usr/local/bin/bat
    fi

    if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
        ln -sf "$(command -v fdfind)" /usr/local/bin/fd
    fi

    # Starship Prompt
    if ! command -v starship &>/dev/null; then
        log_info "Instalando Starship prompt..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y >/dev/null
    fi

    # Oh My Zsh
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
    fi

    # Shell por defecto Zsh
    local current_shell zsh_path
    current_shell=$(getent passwd "$TARGET_USER" | cut -d: -f7)
    zsh_path=$(command -v zsh)
    if [[ "$current_shell" != "$zsh_path" ]]; then
        chsh -s "$zsh_path" "$TARGET_USER"
    fi

    # Registrar instalación en el estado
    set_state_var "MODULE_CORE" "installed"
    log_success "Módulo Core instalado y registrado con éxito."
}

remove_core() {
    log_info "Solicitada desinstalación del módulo Core..."

    # Bloqueo: No desinstalar si hay módulos dependientes activos
    prevent_removal_if "MODULE_DOCKER" "docker.sh"
    prevent_removal_if "MODULE_GIT" "git.sh"
    prevent_removal_if "MODULE_VSCODE" "vscode.sh"

    local pkgs_to_remove=(
        zsh tmux git btop fastfetch iotop sysstat
        tree eza bat fzf ripgrep fd-find
        nmap traceroute mtr dnsutils tcpdump iperf3 jq
    )

    apt-get remove -y "${pkgs_to_remove[@]}" || true

    # Restaurar Bash
    chsh -s /bin/bash "$TARGET_USER"

    # Limpiar binarios y dotfiles
    rm -f /usr/local/bin/starship /usr/local/bin/bat /usr/local/bin/fd
    rm -rf "$TARGET_HOME/.oh-my-zsh"
    rm -f  "$TARGET_HOME/.zshrc" "$TARGET_HOME/.zsh_history"
    rm -rf "$TARGET_HOME/.config/starship.toml" "$TARGET_HOME/.config/btop"

    unset_state_var "MODULE_CORE"
    log_success "Módulo Core desinstalado y desregistrado con éxito."
}

case "$ACTION" in
    install)   install_core ;;
    remove|uninstall) remove_core ;;
    *)
        log_error "Acción desconocida: '$ACTION'. Usa 'install' o 'remove'."
        exit 1
        ;;
esac
