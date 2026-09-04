#!/usr/bin/env bash
# ==============================================================================
# ollama-ui.sh - Interfaz web ultraligera para Ollama (<40 MB)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=../common.sh
source "${SCRIPT_DIR}/../common.sh"

check_root
load_state

ACTION="${1:-install}"
CONTAINER_NAME="ollama-ui-lite"
IMAGE_NAME="ghcr.io/open-webui/open-webui:main-slim" # o una alternativa estática como ghcr.io/ollama-webui/ollama-webui-lite:latest
UI_PORT="3000"

enable_ollama_cors() {
    log_info "Configurando CORS en el servicio nativo de Ollama..."
    local override_dir="/etc/systemd/system/ollama.service.d"
    mkdir -p "$override_dir"

    cat <<EOF > "${override_dir}/environment.conf"
[Service]
Environment="OLLAMA_ORIGINS=*"
Environment="OLLAMA_HOST=0.0.0.0:11434"
EOF

    systemctl daemon-reload
    systemctl restart ollama.service
}

install_ui() {
    log_info "Verificando prerrequisitos para Ollama UI..."
    require_state "MODULE_DOCKER" "installed" "docker.sh"
    require_state "MODULE_OLLAMA" "installed" "ollama.sh"

    # 1. Asegurar que Ollama admita conexiones web locales
    enable_ollama_cors

    # 2. Gestionar contenedor
    if docker ps -a --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
        log_info "El contenedor '$CONTAINER_NAME' ya existe. Asegurando inicio..."
        docker start "$CONTAINER_NAME"
    else
        log_info "Descargando imagen ligera y levantando interfaz..."
        # Corre mapeando el puerto web directo y comunicando con el host
        docker run -d \
            --name "$CONTAINER_NAME" \
            --restart always \
            -p "${UI_PORT}:8080" \
            --add-host=host.docker.internal:host-gateway \
            -e OLLAMA_BASE_URL="http://host.docker.internal:11434" \
            -e WEBUI_AUTH="False" \
            "$IMAGE_NAME"

        log_success "Contenedor '$CONTAINER_NAME' iniciado."
    fi

    set_state_var "MODULE_OLLAMA_UI" "installed"
    log_success "Interfaz disponible en: http://localhost:${UI_PORT}"
}

remove_ui() {
    log_info "Solicitada desinstalación de Ollama UI..."

    if docker ps -a --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
        log_info "Deteniendo y eliminando contenedor..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
    fi

    # Restaurar configuración estándar de systemd para Ollama
    rm -rf /etc/systemd/system/ollama.service.d
    systemctl daemon-reload
    systemctl restart ollama.service 2>/dev/null || true

    unset_state_var "MODULE_OLLAMA_UI"
    log_success "Módulo Ollama UI desinstalado con éxito."
}

case "$ACTION" in
    install)          install_ui ;;
    remove|uninstall) remove_ui ;;
    *)
        log_error "Acción no válida: '$ACTION'. Usa 'install' o 'remove'."
        exit 1
        ;;
esac
