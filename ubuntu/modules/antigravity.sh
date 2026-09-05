#!/usr/bin/env bash
# ==============================================================================
# antigravity.sh - Instalación directa de Antigravity IDE Standalone (v2.5.5)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=../common.sh
source "${SCRIPT_DIR}/../common.sh"

check_root
load_state

ACTION="${1:-install}"
INSTALL_DIR="/opt/antigravity-ide"

# Extensiones estándar a configurar en Antigravity IDE
ANTIGRAVITY_EXTENSIONS=(
    "crsx.ag-usage"
    "ms-azuretools.vscode-docker"
    "mermaidchart.vscode-mermaid-chart"
    "dbaeumer.vscode-eslint"
    "esbenp.prettier-vscode"
    "google.google-antigravity"
)

detect_arch_slug() {
    case "$(uname -m)" in
        x86_64)        echo "linux-x64" ;;
        aarch64|arm64) echo "linux-arm" ;;
        *)
            log_error "Arquitectura no soportada: $(uname -m)"
            exit 1
            ;;
    esac
}

install_antigravity() {
    log_info "Verificando prerrequisitos para Antigravity IDE..."
    require_state "MODULE_CORE" "installed" "core.sh"

    local arch_slug
    arch_slug=$(detect_arch_slug)

    # 1. Descargar e instalar Standalone IDE 2.5.5
    log_info "Descargando Antigravity IDE 2.5.5 (${arch_slug})..."
    local download_url="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.5.5-4923483625488384/${arch_slug}/Antigravity%20IDE.tar.gz"
    local temp_tar="/tmp/antigravity.tar.gz"

    curl -fSL "$download_url" -o "$temp_tar"

    log_info "Extrayendo binarios en $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    tar -xzf "$temp_tar" -C "$INSTALL_DIR" --strip-components=1
    rm -f "$temp_tar"

    # 2. Configurar symlink global en el PATH
    ln -sf "${INSTALL_DIR}/antigravity" /usr/local/bin/antigravity

    # 3. Crear lanzador de escritorio (.desktop)
    cat <<EOF > /usr/share/applications/antigravity.desktop
[Desktop Entry]
Name=Antigravity IDE
Comment=Google Antigravity Standalone IDE
Exec=/usr/local/bin/antigravity %F
Icon=${INSTALL_DIR}/resources/app/resources/linux/code.png
Type=Application
StartupNotify=true
Categories=Development;IDE;
MimeType=text/plain;inode/directory;
EOF
    chmod 644 /usr/share/applications/antigravity.desktop

    # 4. Instalar extensiones exclusivamente dentro de Antigravity IDE
    log_info "Instalando extensiones dentro de Antigravity IDE para $TARGET_USER..."
    for ext in "${ANTIGRAVITY_EXTENSIONS[@]}"; do
        log_info "Instalando extensión: $ext..."
        sudo -u "$TARGET_USER" /usr/local/bin/antigravity --install-extension "$ext" --force &>/dev/null || {
            log_warn "No se pudo instalar $ext (puede añadirse luego desde el IDE)."
        }
    done

    set_state_var "MODULE_ANTIGRAVITY" "installed"
    log_success "Antigravity IDE 2.5.5 instalado y registrado con éxito."
}

remove_antigravity() {
    log_info "Solicitada desinstalación de Antigravity IDE..."

    rm -rf "$INSTALL_DIR"
    rm -f /usr/local/bin/antigravity
    rm -f /usr/share/applications/antigravity.desktop
    rm -rf "${TARGET_HOME}/.antigravity"

    unset_state_var "MODULE_ANTIGRAVITY"
    log_success "Antigravity IDE desinstalado y desregistrado con éxito."
}

case "$ACTION" in
    install)          install_antigravity ;;
    remove|uninstall) remove_antigravity ;;
    *)
        log_error "Acción no válida: '$ACTION'. Usa 'install' o 'remove'."
        exit 1
        ;;
esac
