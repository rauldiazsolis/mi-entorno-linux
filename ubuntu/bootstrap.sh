#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
REPO_DIR="$TARGET_HOME/mi-entorno-linux"
REPO_URL="https://github.com/rauldiazsolis/mi-entorno-linux.git"

echo "--> [BOOTSTRAP] Asegurando dependencias mínimas (git, curl)..."
apt-get update -y
apt-get install -y --no-install-recommends git curl ca-certificates

if [[ ! -d "$REPO_DIR" ]]; then
    echo "--> [BOOTSTRAP] Clonando repositorio en $REPO_DIR..."
    sudo -u "$TARGET_USER" git clone "$REPO_URL" "$REPO_DIR"
else
    echo "--> [BOOTSTRAP] Actualizando repositorio local..."
    sudo -u "$TARGET_USER" git -C "$REPO_DIR" pull --ff-only || true
fi

chmod +x "$REPO_DIR/ubuntu/common.sh" "$REPO_DIR"/ubuntu/modules/*.sh 2>/dev/null || true

# Ejecutar el módulo solicitado o la instalación completa por defecto
cd "$REPO_DIR/ubuntu"
MODULE="${1:-modules/core.sh}"
ACTION="${2:-install}"

echo "--> [BOOTSTRAP] Ejecutando: $MODULE $ACTION"
exec "./$MODULE" "$ACTION"
