#!/usr/bin/env bash
# ==============================================================================
# reset_system.sh - Limpieza superficial y segura del Bloque 1
# ==============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] Este script debe ejecutarse como root (usa sudo)." >&2
   exit 1
fi

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

echo "==> Iniciando reseteo superficial..."

# 1. Paquetes seguros a desinstalar (excluidos: wget, openssl, ca-certificates, gnupg)
PACKAGES_TO_REMOVE=(
    zsh tmux git btop fastfetch iotop sysstat
    tree eza bat fzf ripgrep fd-find
    nmap traceroute mtr dnsutils tcpdump iperf3 jq
)

echo "--> Desinstalando herramientas del Bloque 1..."
apt-get remove -y "${PACKAGES_TO_REMOVE[@]}" || true

# 2. Restaurar shell por defecto a Bash
echo "--> Restaurando shell por defecto a Bash..."
chsh -s /bin/bash "$TARGET_USER"

# 3. Eliminar binarios externos y enlaces simbólicos creados
rm -f /usr/local/bin/starship
rm -f /usr/local/bin/bat
rm -f /usr/local/bin/fd

# 4. Limpiar dotfiles y configuraciones del usuario
echo "--> Limpiando dotfiles en $TARGET_HOME..."
rm -rf "$TARGET_HOME/.oh-my-zsh"
rm -f  "$TARGET_HOME/.zshrc" "$TARGET_HOME/.zsh_history"
rm -rf "$TARGET_HOME/.config/starship.toml" "$TARGET_HOME/.config/btop"

echo "==> Sistema limpio (superficial) listo para volver a probar."
