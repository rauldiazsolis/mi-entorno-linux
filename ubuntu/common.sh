#!/usr/bin/env bash
# ==============================================================================
# common.sh - Utilidades compartidas, validación y gestión de estado
# ==============================================================================
set -euo pipefail

STATE_FILE="/etc/workstation.state"

# Formato visual de logs
log_info()    { echo -e "\e[34m[INFO]\e[0m $*"; }
log_success() { echo -e "\e[32m[OK]\e[0m $*"; }
log_warn()    { echo -e "\e[33m[WARN]\e[0m $*"; }
log_error()   { echo -e "\e[31m[ERROR]\e[0m $*" >&2; }

# Validar que se ejecute con privilegios root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse con privilegios de root: sudo $0"
        exit 1
    fi
}

# Obtener usuario y home real independientemente de sudo
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

# Inicializar y cargar archivo de estado
load_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        touch "$STATE_FILE"
        chmod 644 "$STATE_FILE"
    fi
    # shellcheck source=/dev/null
    source "$STATE_FILE"
}

# Guardar o actualizar una variable en el archivo de estado
set_state_var() {
    local key="$1"
    local value="$2"
    load_state

    if grep -q "^${key}=" "$STATE_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$STATE_FILE"
    else
        echo "${key}=${value}" >> "$STATE_FILE"
    fi
    export "${key}=${value}"
}

# Eliminar una variable del archivo de estado
unset_state_var() {
    local key="$1"
    if [[ -f "$STATE_FILE" ]]; then
        sed -i "/^${key}=/d" "$STATE_FILE"
    fi
    unset "${key}" || true
}

# Validar prerrequisito obligatorio antes de instalar
require_state() {
    local key="$1"
    local expected_val="${2:-true}"
    local module_hint="$3"
    load_state

    local current_val="${!key:-}"
    if [[ "$current_val" != "$expected_val" ]]; then
        log_error "Prerrequisito no cumplido: Se requiere que '${key}' sea '${expected_val}'."
        log_error "Debes ejecutar previamente el módulo: ${module_hint}"
        exit 1
    fi
}

# Validar que no existan módulos dependientes antes de desinstalar
prevent_removal_if() {
    local key="$1"
    local module_name="$2"
    load_state

    local current_val="${!key:-}"
    if [[ "$current_val" == "installed" || "$current_val" == "true" ]]; then
        log_error "Bloqueo de desinstalación: '${module_name}' sigue activo y depende de este módulo."
        log_error "Desinstala primero '${module_name}' antes de continuar."
        exit 1
    fi
}
