#!/usr/bin/env bash
# ==============================================================================
# ollama.sh - Servicio local Ollama (Headless API)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=../common.sh
source "${SCRIPT_DIR}/../common.sh"

check_root
load_state

ACTION="${1:-install}"

install_ollama() {
    log_info "Verificando prerrequisitos para Ollama..."
    require_state "MODULE_CORE" "installed" "core.sh"
    require_state "GPU_DECIDED" "true" "gpu.sh"

    if [[ "${GPU_DRIVER_INSTALLED:-false}" == "true" ]]; then
        log_success "Driver NVIDIA detectado: Ollama se ejecutará con aceleración por GPU."
    else
        log_warn "Driver NVIDIA no disponible: Ollama se ejecutará en modo CPU."
    fi

    # 1. Instalar binario oficial y servicio systemd
    if command -v ollama &>/dev/null; then
        log_info "Ollama ya está instalado en el sistema. Omitiendo descarga..."
    else
        log_info "Descargando e instalando Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh
        log_success "Ollama instalado correctamente."
    fi

    # 2. Iniciar y habilitar servicio systemd nativo
    systemctl enable ollama.service
    systemctl restart ollama.service

    # 3. Comprobar disponibilidad del daemon
    log_info "Verificando daemon en localhost:11434..."
    local retries=10
    until curl -s http://localhost:11434/api/version &>/dev/null || [[ $retries -eq 0 ]]; do
        sleep 1
        retries=$((retries - 1))
    done

    if [[ $retries -eq 0 ]]; then
        log_warn "El socket demoró en responder, pero el servicio systemd está activo."
    else
        log_success "Servicio Ollama operativo en http://localhost:11434"
    fi

    set_state_var "MODULE_OLLAMA" "installed"
    log_success "Módulo Ollama completado y registrado."
}

remove_ollama() {
    log_info "Solicitada desinstalación del módulo Ollama..."

    prevent_removal_if "MODULE_OPENWEBUI" "open-webui.sh"
    prevent_removal_if "MODULE_CONTINUE" "continue.sh"

    log_info "Deteniendo servicio systemd..."
    systemctl stop ollama.service 2>/dev/null || true
    systemctl disable ollama.service 2>/dev/null || true

    log_info "Purgando binarios y datos..."
    rm -f /usr/local/bin/ollama
    rm -f /etc/systemd/system/ollama.service
    systemctl daemon-reload

    rm -rf /usr/share/ollama
    rm -rf "$TARGET_HOME/.ollama"

    userdel -r ollama 2>/dev/null || true
    groupdel ollama 2>/dev/null || true

    unset_state_var "MODULE_OLLAMA"
    log_success "Módulo Ollama desinstalado y desregistrado con éxito."
}

case "$ACTION" in
    install)          install_ollama ;;
    remove|uninstall) remove_ollama ;;
    *)
        log_error "Acción no válida: '$ACTION'. Usa 'install' o 'remove'."
        exit 1
        ;;
esac
