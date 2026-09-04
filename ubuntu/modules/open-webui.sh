#!/usr/bin/env bash
# ==============================================================================
# open-webui.sh - Interfaz web para Ollama mediante Docker
# ==============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=../common.sh
source "${SCRIPT_DIR}/../common.sh"

check_root
load_state

ACTION="${1:-install}"
CONTAINER_NAME="open-webui"
IMAGE_NAME="ghcr.io/open-webui/open-webui:main"
VOLUME_NAME="open-webui-data"

install_ui() {
    log_info "Verificando prerrequisitos para la interfaz gráfica de Ollama..."
    require_state "MODULE_DOCKER" "installed" "docker.sh"
    require_state "MODULE_OLLAMA" "installed" "ollama.sh"

    # 1. Comprobar si el contenedor ya existe
    if docker ps -a --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
        log_info "El contenedor '$CONTAINER_NAME' ya existe."
        if ! docker ps --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
            log_info "Iniciando contenedor '$CONTAINER_NAME'..."
            docker start "$CONTAINER_NAME"
        fi
    else
        log_info "Descargando imagen y creando contenedor Open WebUI..."
        # Corre en la red del host para alcanzar localhost:11434 directamente sin tocar VRAM
        docker run -d \
            --network=host \
            -v "${VOLUME_NAME}:/app/backend/data" \
            -e OLLAMA_BASE_URL="http://127.0.0.1:11434" \
            --name "$CONTAINER_NAME" \
            --restart always \
            "$IMAGE_NAME"

        log_success "Contenedor '$CONTAINER_NAME' creado y puesto en ejecución."
    fi

    # 2. Esperar respuesta de la interfaz web en localhost:8080
    log_info "Esperando disponibilidad de la interfaz en http://localhost:8080..."
    local retries=15
    until curl -s http://localhost:8080/health &>/dev/null || [[ $retries -eq 0 ]]; do
        sleep 2
        retries=$((retries - 1))
    done

    if [[ $retries -eq 0 ]]; then
        log_warn "La UI demoró en reportar salud, pero el contenedor está activo."
    else
        log_success "Open WebUI listo y disponible en http://localhost:8080"
    fi

    set_state_var "MODULE_OPENWEBUI" "installed"
    log_success "Módulo Open WebUI completado y registrado."
}

remove_ui() {
    log_info "Solicitada desinstalación de Open WebUI..."

    if docker ps -a --format '{{.Names}}' | grep -qw "$CONTAINER_NAME"; then
        log_info "Deteniendo y eliminando contenedor '$CONTAINER_NAME'..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
    fi

    # Limpiar volumen de datos persistentes
    if docker volume ls -q | grep -qw "$VOLUME_NAME"; then
        log_info "Eliminando volumen de datos Docker '$VOLUME_NAME'..."
        docker volume rm "$VOLUME_NAME" 2>/dev/null || true
    fi

    unset_state_var "MODULE_OPENWEBUI"
    log_success "Módulo Open WebUI desinstalado y desregistrado con éxito."
}

case "$ACTION" in
    install)          install_ui ;;
    remove|uninstall) remove_ui ;;
    *)
        log_error "Acción no válida: '$ACTION'. Usa 'install' o 'remove'."
        exit 1
        ;;
esac
