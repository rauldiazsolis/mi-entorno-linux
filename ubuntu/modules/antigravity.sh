#!/usr/bin/env bash
# ==============================================================================
# antigravity.sh - Google Antigravity IDE y extensiones de plataforma
# ==============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=../common.sh
source "${SCRIPT_DIR}/../common.sh"

check_root
load_state

ACTION="${1:-install}"

# Extensiones para el entorno de trabajo en Antigravity
ANTIGRAVITY_EXTENSIONS=(
    "crsx.ag-usage"
    "ms-azuretools.vscode-docker"
    "mermaidchart.vscode-mermaid-chart"
    "dbaeumer.vscode-eslint"
    "esbenp.prettier-vscode"
)

install_antigravity() {
    log_info "Verificando prerrequisitos para Google Antigravity IDE..."
    require_state "MODULE_CORE" "installed" "core.sh"
    require_state "MODULE_GIT" "installed" "git.sh"

    # 1. Configurar repositorio oficial APT de Google Antigravity
    if ! command -v antigravity &>/dev/null; then
        log_info "Configurando repositorio de Google Antigravity..."
        install -m 0755 -d /etc/apt/keyrings

        curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg \
            | gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg
        chmod 644 /etc/apt/keyrings/antigravity-repo-key.gpg

        echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" \
            | tee /etc/apt/sources.list.d/antigravity.list > /dev/null

        apt-get update -y
        log_info "Instalando paquete antigravity..."
        apt-get install -y --no-install-recommends antigravity
        log_success "Google Antigravity instalado correctamente."
    else
        log_info "Antigravity ya se encuentra instalado en el sistema."
    fi

    # 2. Instalar extensiones para el usuario objetivo
    log_info "Instalando extensiones en Antigravity para el usuario $TARGET_USER..."
    for ext in "${ANTIGRAVITY_EXTENSIONS[@]}"; do
        log_info "Instalando extensión: $ext..."
        sudo -u "$TARGET_USER" antigravity --install-extension "$ext" --force &>/dev/null || {
            log_warn "No se pudo preinstalar la extensión: $ext (podrá instalarse luego desde la UI)."
        }
    done
    log_success "Extensiones configuradas en Antigravity IDE."

    set_state_var "MODULE_ANTIGRAVITY" "installed"
    log_success "Módulo Antigravity completado y registrado."
}

remove_antigravity() {
    log_info "Solicitada desinstalación de Google Antigravity..."

    log_info "Eliminando paquete antigravity y repositorios..."
    apt-get remove -y antigravity || true
    rm -f /etc/apt/sources.list.d/antigravity.list
    rm -f /etc/apt/keyrings/antigravity-repo-key.gpg

    log_info "Limpiando directorios de configuración de $TARGET_USER..."
    rm -rf "${TARGET_HOME}/.antigravity"
    rm -rf "${TARGET_HOME}/.config/Antigravity"

    unset_state_var "MODULE_ANTIGRAVITY"
    log_success "Módulo Antigravity desinstalado con éxito."
}

case "$ACTION" in
    install)          install_antigravity ;;
    remove|uninstall) remove_antigravity ;;
    *)
        log_error "Acción no válida: '$ACTION'. Usa 'install' o 'remove'."
        exit 1
        ;;
esac
