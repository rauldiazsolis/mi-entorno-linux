#!/usr/bin/env bash
# ==============================================================================
# reset_system.sh - Limpieza segura de herramientas y Docker
# ==============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] Este script debe ejecutarse como root (usa sudo)." >&2
   exit 1
fi

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
STATE_FILE="/etc/workstation.state"

echo "==> Iniciando reseteo del sistema..."

# 1. Detener servicios antes de desinstalar
echo "--> Deteniendo servicios..."
systemctl stop docker.service docker.socket 2>/dev/null || true

# 2. Desinstalar paquetes de Bloque 1 y Bloque 2 (Docker)
PACKAGES_TO_REMOVE=(
    # NVidia Docker Toolkit
    nvidia-container-toolkit libnvidia-container-tools libnvidia-container1
    # Docker oficial
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    # Herramientas del sistema y CLI
    zsh tmux git btop fastfetch iotop sysstat
    tree eza bat fzf ripgrep fd-find
    nmap traceroute mtr dnsutils tcpdump iperf3 jq
)

echo "--> Desinstalando paquetes de la estación de trabajo..."
apt-get remove -y "${PACKAGES_TO_REMOVE[@]}" || true

# 3. Limpiar repositorios externos y llaves GPG
echo "--> Eliminando fuentes y llaves de APT añadidas..."
rm -f /etc/apt/sources.list.d/docker.list
rm -f /etc/apt/keyrings/docker.asc

# 4. Eliminar archivo de estado de decisiones (GPU / Ollama)
if [[ -f "$STATE_FILE" ]]; then
    echo "--> Eliminando archivo de estado: $STATE_FILE"
    rm -f "$STATE_FILE"
fi

# 5. Restaurar shell por defecto a Bash
echo "--> Restaurando shell por defecto a Bash..."
chsh -s /bin/bash "$TARGET_USER"

# 6. Eliminar binarios externos y enlaces simbólicos creados
rm -f /usr/local/bin/starship
rm -f /usr/local/bin/bat
rm -f /usr/local/bin/fd

# 7. Limpiar dotfiles y configuraciones del usuario
echo "--> Limpiando dotfiles en $TARGET_HOME..."
rm -rf "$TARGET_HOME/.oh-my-zsh"
rm -f  "$TARGET_HOME/.zshrc" "$TARGET_HOME/.zsh_history"
rm -rf "$TARGET_HOME/.config/starship.toml" "$TARGET_HOME/.config/btop"

rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list
rm -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
rm -f /etc/apt/keyrings/nvidia-container-toolkit.asc

echo "==> Sistema reseteado con éxito."
