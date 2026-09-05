#!/usr/bin/env bash
# ==============================================================================
# install.sh - Orquestador idempotente de aprovisionamiento
# ==============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

check_root
load_state

# Lista ordenada de módulos a desplegar
MODULES=(
    "core.sh"
    "gpu.sh"
    "git.sh"
    "docker.sh"
    "vscode.sh"
    "antigravity.sh"
    "portainer.sh"
)

log_info "Iniciando aprovisionamiento de mi-entorno-linux..."

for mod in "${MODULES[@]}"; do
    mod_path="${SCRIPT_DIR}/modules/${mod}"
    
    if [[ ! -f "$mod_path" ]]; then
        log_warn "Módulo no encontrado: $mod. Omitiendo..."
        continue
    fi

    chmod +x "$mod_path"
    log_info "--------------------------------------------------------"
    log_info "Procesando módulo: $mod"
    log_info "--------------------------------------------------------"
    
    # Ejecuta el módulo pasando la acción install
    "$mod_path" install
done

log_success "Aprovisionamiento completado con éxito."
