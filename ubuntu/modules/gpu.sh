#!/usr/bin/env bash
# ==============================================================================
# gpu.sh - Gestión, detección y controladores de GPU NVIDIA
# ==============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=../common.sh
source "${SCRIPT_DIR}/../common.sh"

check_root
load_state

ACTION="${1:-install}"

install_gpu() {
    log_info "Verificando hardware de video y estado de controladores..."

    if [[ "${GPU_DECIDED:-false}" == "true" ]]; then
        log_info "Decisión de GPU ya procesada previamente (DRIVER_INSTALLED=${GPU_DRIVER_INSTALLED:-false})."
        return 0
    fi

    # 1. Comprobar presencia física de GPU NVIDIA
    if ! lspci | grep -qi "nvidia"; then
        log_warn "No se detectó GPU NVIDIA dedicada en este equipo."
        set_state_var "GPU_NVIDIA_PRESENT" "false"
        set_state_var "GPU_DRIVER_INSTALLED" "false"
        set_state_var "GPU_DECIDED" "true"
        return 0
    fi

    set_state_var "GPU_NVIDIA_PRESENT" "true"

    # 2. Comprobar si los controladores privativos ya responden
    if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
        local gpu_model
        gpu_model=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)
        log_success "GPU NVIDIA detectada: ${gpu_model}"
        log_success "Controladores privativos activos y operativos."
        set_state_var "GPU_DRIVER_INSTALLED" "true"
        set_state_var "GPU_DECIDED" "true"
        return 0
    fi

    # 3. Hardware presente pero sin driver privativo activo
    log_warn "Se detectó GPU NVIDIA, pero los controladores oficiales no están activos (ej. nouveau en uso)."
    echo ""
    echo "¿Deseas instalar los controladores privativos recomendados mediante ubuntu-drivers?"

    local choice
    read -rp "[s/N]: " choice </dev/tty
    echo ""

    case "$choice" in
        [sS][iI]|[sS])
            log_info "Instalando controladores recomendados vía ubuntu-drivers..."
            ubuntu-drivers install
            set_state_var "GPU_DRIVER_INSTALLED" "true"
            set_state_var "GPU_DECIDED" "true"
            log_warn "Controladores instalados. Es obligatorio reiniciar el sistema."
            log_warn "Ejecuta: sudo reboot"
            log_warn "Al reiniciar, continúa con los siguientes módulos."
            exit 0
            ;;
        *)
            log_info "Instalación de drivers privativos omitida por el usuario."
            set_state_var "GPU_DRIVER_INSTALLED" "false"
            set_state_var "GPU_DECIDED" "true"
            ;;
    esac

    log_success "Configuración de GPU registrada."
}

remove_gpu() {
    log_info "Solicitada desinstalación/reseteo del estado de GPU..."

    prevent_removal_if "MODULE_DOCKER" "docker.sh"
    prevent_removal_if "MODULE_OLLAMA" "ollama.sh"

    log_info "Eliminando marcas de estado de GPU..."
    unset_state_var "GPU_DECIDED"
    unset_state_var "GPU_NVIDIA_PRESENT"
    unset_state_var "GPU_DRIVER_INSTALLED"

    log_success "Estado de GPU reseteado con éxito."
}

case "$ACTION" in
    install)          install_gpu ;;
    remove|uninstall) remove_gpu ;;
    *)
        log_error "Acción desconocida: '$ACTION'. Usa 'install' o 'remove'."
        exit 1
        ;;
esac
