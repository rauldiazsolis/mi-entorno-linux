#!/usr/bin/env bash
# ==============================================================================
# ollama.sh - Servicio local Ollama y modelos LLM
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

    if [[ "${OLLAMA_ENABLED:-false}" != "true" ]]; then
        log_info "GPU NVIDIA no habilitada o ausente. Omitiendo instalación de Ollama."
        return 0
    fi

    # 1. Instalar binario y servicio systemd oficial
    if command -v ollama &>/dev/null; then
        log_info "Ollama ya está instalado en el sistema. Omitiendo descarga..."
    else
        log_info "Instalando Ollama como servicio nativo..."
        curl -fsSL https://ollama.com/install.sh | sh
        log_success "Binario de Ollama instalado."
    fi

    # 2. Habilitar y levantar servicio
    systemctl enable ollama.service
    systemctl restart ollama.service

    # 3. Esperar que el socket HTTP responda en localhost:11434
    log_info "Esperando disponibilidad del daemon de Ollama..."
    local retries=10
    until curl -s http://localhost:11434/api/version &>/dev/null || [[ $retries -eq 0 ]]; do
        sleep 1
        retries=$((retries - 1))
    done

    if [[ $retries -eq 0 ]]; then
        log_warn "El servicio Ollama demoró en responder, pero el daemon sigue en ejecución."
    else
        log_success "Servicio Ollama activo y respondiendo en localhost:11434."
    fi

    set_state_var "MODULE_OLLAMA" "installed"
    log_success "Módulo Ollama completado y registrado."
}

remove_ollama() {
    log_info "Solicitada desinstalación del módulo Ollama..."

    # Bloqueo inverso si módulos futuros dependen de Ollama
    prevent_removal_if "MODULE_CONTINUE" "continue.sh"

    log_info "Deteniendo y deshabilitando servicio systemd..."
    systemctl stop ollama.service 2>/dev/null || true
    systemctl disable ollama.service 2>/dev/null || true

    log_info "Purgando binario, servicio y modelos descargados..."
    rm -f /usr/local/bin/ollama
    rm -f /etc/systemd/system/ollama.service
    systemctl daemon-reload

    # Purgar datos y modelos almacenados
    rm -rf /usr/share/ollama
    rm -rf "$TARGET_HOME/.ollama"

    # Eliminar usuario de sistema si existe
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
