#!/usr/bin/env bash
# ==============================================================================
# gpu.sh - Gestión, detección y controladores de GPU NVIDIA
# ==============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# Cargar librería común
# shellcheck source=../common.sh
source "${SCRIPT_DIR}/../common.sh"

check_root
load_state

ACTION="${1:-install}"

install_gpu() {
    log_info "Verificando hardware de video y controladores..."

    if [[ "${GPU_DECIDED:-false}" == "true" ]]; then
        log_info "Decisión de GPU ya configurada previamente (OLLAMA_ENABLED=${OLLAMA_ENABLED:-false})."
        return 0
    fi

    # 1. Comprobar presencia física de placa NVIDIA
    if ! lspci | grep -qi "nvidia"; then
        log_warn "No se detectó GPU NVIDIA dedicada en este equipo."
        log_info "Marcando aceleración como no disponible..."
        set_state_var "OLLAMA_ENABLED" "false"
        set_state_var "GPU_DECIDED" "true"
        return 0
    fi

    # 2. Comprobar si los controladores privativos ya están activos
    if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
        log_success "GPU NVIDIA detectada y controladores funcionando correctamente."
        set_state_var "OLLAMA_ENABLED" "true"
        set_state_var "GPU_DECIDED" "true"
        return 0
    fi

    # 3. Hardware presente pero sin controladores privativos activos
    log_warn "Se detectó GPU NVIDIA, pero usa drivers libres (nouveau) o no están activos."
    echo ""
    echo "Para aceleración local por hardware es indispensable instalar los drivers privativos y reiniciar."

    local choice
    read -rp "¿Deseas instalar los controladores privativos recomendados ahora? [s/N]: " choice </dev/tty
    echo ""

    case "$choice" in
        [sS][iI]|[sS])
            log_info "Instalando controladores recomendados vía ubuntu-drivers..."
            ubuntu-drivers install
            set_state_var "GPU_DECIDED" "true"
            set_state_var "OLLAMA_ENABLED" "true"
            log_warn "Controladores instalados. Es obligatorio reiniciar el sistema."
            log_warn "Ejecuta: sudo reboot"
            log_warn "Al reiniciar, continúa ejecutando el siguiente módulo: ./core.sh install"
            exit 0
            ;;
        *)
            log_info "Instalación de drivers privativos omitida por el usuario."
            set_state_var "GPU_DECIDED" "true"
            set_state_var "OLLAMA_ENABLED" "false"
            ;;
    esac

    log_success "Configuración de GPU finalizada."
}

remove_gpu() {
    log_info "Solicitada desinstalación/reseteo de la configuración de GPU..."

    # Validación inversa: no permitir resetear GPU si Docker u Ollama siguen registrados
    prevent_removal_if "MODULE_OLLAMA" "ollama.sh"
    prevent_removal_if "MODULE_DOCKER" "docker.sh"

    log_info "Eliminando registros de decisión de GPU..."
    unset_state_var "GPU_DECIDED"
    unset_state_var "OLLAMA_ENABLED"

    log_success "Estado de GPU reseteado con éxito."
}

case "$ACTION" in
    install)
        install_gpu
        ;;
    remove|uninstall)
        remove_gpu
        ;;
    *)
        log_error "Acción desconocida: '$ACTION'. Usa 'install' o 'remove'."
        exit 1
        ;;
esac
