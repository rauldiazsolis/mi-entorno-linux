#!/usr/bin/env bash
# ==============================================================================
# reset_system.sh - Limpieza superficial, segura y de estados
# ==============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] Este script debe ejecutarse como root (usa sudo)." >&2
   exit 1
fi

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
STATE_FILE="/etc/workstation.state"

echo "==> Iniciando reseteo superficial y de configuración..."

# 1. Purgar archivo de estado para permitir nuevas decisiones
if [[ -f "$STATE_FILE" ]]; then
    echo "--> Eliminando archivo de estado: $STATE_FILE"
    rm -f "$STATE_FILE"
fi

# 2. Desinstalación segura del Bloque 1
PACKAGES_TO_REMOVE=(
    zsh tmux git btop fastfetch iotop sysstat
    tree eza bat fzf ripgrep fd-find
    nmap traceroute mtr dnsutils tcpdump iperf3 jq
)

echo "--> Desinstalando herramientas del Bloque 1..."
apt-get remove -y "${PACKAGES_TO_REMOVE[@]}" || true

# 3. Restaurar shell por defecto a Bash
echo "--> Restaurando shell por defecto a Bash..."
chsh -s /bin/bash "$TARGET_USER"

# 4. Eliminar binarios externos y enlaces simbólicos creados
rm -f /usr/local/bin/starship
rm -f /usr/local/bin/bat
rm -f /usr/local/bin/fd

# 5. Limpiar dotfiles del usuario
echo "--> Limpiando dotfiles en $TARGET_HOME..."
rm -rf "$TARGET_HOME/.oh-my-zsh"
rm -f  "$TARGET_HOME/.zshrc" "$TARGET_HOME/.zsh_history"
rm -rf "$TARGET_HOME/.config/starship.toml" "$TARGET_HOME/.config/btop"

echo "==> Sistema limpio y estados reseteados."
