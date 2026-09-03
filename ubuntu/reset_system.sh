#!/usr/bin/env bash
# ==============================================================================
# reset_system.sh - Limpieza de herramientas CLI y entorno base
# ==============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] Este script debe ejecutarse como root (usa sudo)." >&2
   exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

echo "==> Iniciando limpieza del sistema..."

# 1. Paquetes instalados en el bloque 1
PACKAGES_TO_REMOVE=(
    zsh tmux btop fastfetch iotop sysstat
    tree eza bat fzf ripgrep fd-find
    curl wget net-tools iproute2 nmap traceroute mtr dnsutils tcpdump iperf3
    unzip p7zip-full jq openssl ca-certificates
)

echo "--> Purgando paquetes del sistema..."
apt-get purge -y "${PACKAGES_TO_REMOVE[@]}" || true
apt-get autoremove --purge -y
apt-get clean

# 2. Restaurar shell predeterminado a Bash para el usuario
echo "--> Restaurando shell por defecto a Bash..."
chsh -s /bin/bash "$REAL_USER"

# 3. Eliminar configuraciones y carpetas residuales en HOME
echo "--> Limpiando dotfiles y configuraciones en $REAL_HOME..."
rm -rf "$REAL_HOME/.oh-my-zsh"
rm -f  "$REAL_HOME/.zshrc" "$REAL_HOME/.zsh_history"
rm -rf "$REAL_HOME/.config/starship.toml" "$REAL_HOME/.config/btop"
rm -f  /usr/local/bin/starship

echo "==> Sistema limpio y listo para volver a probar."
