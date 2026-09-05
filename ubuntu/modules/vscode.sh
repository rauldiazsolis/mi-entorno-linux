#!/usr/bin/env bash
# ==============================================================================
# vscode.sh - Instalación de Visual Studio Code y extensiones de plataforma
# ==============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=../common.sh
source "${SCRIPT_DIR}/../common.sh"

check_root
load_state

ACTION="${1:-install}"

# Extensiones esenciales de infraestructura/entorno
GLOBAL_EXTENSIONS=(
    "ms-azuretools.vscode-docker"
    "ms-vscode-remote.remote-containers"
    "eamodio.gitlens"
)

install_vscode() {
    log_info "Verificando prerrequisitos para Visual Studio Code..."
    require_state "MODULE_CORE" "installed" "core.sh"
    require_state "MODULE_GIT" "installed" "git.sh"

    # 1. Configurar repositorio oficial APT de Microsoft
    if ! command -v code &>/dev/null; then
        log_info "Configurando repositorio de Microsoft para VS Code..."
        install -m 0755 -d /etc/apt/keyrings

        if [[ ! -f /etc/apt/keyrings/packages.microsoft.gpg ]]; then
            curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
                | gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg
            chmod 644 /etc/apt/keyrings/packages.microsoft.gpg
        fi

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
            | tee /etc/apt/sources.list.d/vscode.list > /dev/null

        apt-get update -y
        log_info "Instalando paquete code..."
        apt-get install -y --no-install-recommends code
        log_success "Visual Studio Code instalado correctamente."
    else
        log_info "VS Code ya está instalado en el sistema."
    fi

    # 2. Instalar extensiones globales en espacio de usuario
    log_info "Instalando extensiones de infraestructura para $TARGET_USER..."
    for ext in "${GLOBAL_EXTENSIONS[@]}"; do
        log_info "Verificando extensión: $ext..."
        sudo -u "$TARGET_USER" code --install-extension "$ext" --force &>/dev/null || {
            log_warn "No se pudo preinstalar la extensión $ext (puede instalarse luego)."
        }
    done
    log_success "Extensiones base configuradas."

    set_state_var "MODULE_VSCODE" "installed"
    log_success "Módulo VS Code completado y registrado."
}

remove_vscode() {
    log_info "Solicitada desinstalación del módulo VS Code..."

    log_info "Eliminando paquete code..."
    apt-get remove -y code || true
    rm -f /etc/apt/sources.list.d/vscode.list
    rm -f /etc/apt/keyrings/packages.microsoft.gpg

    log_info "Limpiando configuración y extensiones del usuario $TARGET_USER..."
    rm -rf "$TARGET_HOME/.vscode"
    rm -rf "$TARGET_HOME/.config/Code"

    unset_state_var "MODULE_VSCODE"
    log_success "Módulo VS Code desinstalado con éxito."
}

case "$ACTION" in
    install)          install_vscode ;;
    remove|uninstall) remove_vscode ;;
    *)
        log_error "Acción no válida: '$ACTION'. Usa 'install' o 'remove'."
        exit 1
        ;;
esac
