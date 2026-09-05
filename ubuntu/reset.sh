#!/usr/bin/env bash
# ==============================================================================
# reset.sh - Desinstalación en orden inverso y limpieza de estado
# ==============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

check_root
load_state

# Orden inverso de desinstalación para respetar dependencias
MODULES_REVERSE=(
    "portainer.sh"
    "antigravity.sh"
    "vscode.sh"
    "docker.sh"
    "git.sh"
    "gpu.sh"
    "core.sh"
)

log_info "Iniciando reversión completa de mi-entorno-linux..."

for mod in "${MODULES_REVERSE[@]}"; do
    mod_path="${SCRIPT_DIR}/modules/${mod}"
    
    if [[ ! -f "$mod_path" ]]; then
        continue
    fi

    chmod +x "$mod_path"
    log_info "Revisando y removiendo módulo: $mod"
    "$mod_path" remove || log_warn "Aviso al desinstalar $mod (continuando...)"
done

log_info "Limpiando archivo de estado global..."
rm -f "$STATE_FILE"

log_success "Entorno revertido por completo."
