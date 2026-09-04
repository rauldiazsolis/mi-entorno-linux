#!/usr/bin/env bash
# ==============================================================================
# reset_system.sh - Limpieza segura de herramientas, Docker y Ollama
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

# 1. Detener y deshabilitar servicios
echo "--> Deteniendo servicios activos..."
if systemctl is-active --quiet ollama.service 2>/dev/null; then
    systemctl stop ollama.service
    systemctl disable ollama.service 2>/dev/null || true
fi
systemctl stop docker.service docker.socket 2>/dev/null || true

# 2. Desinstalar paquetes de APT (Bloque 1 y Bloque 2)
PACKAGES_TO_REMOVE=(
    # Github
    gh
    # NVIDIA Container Toolkit
    nvidia-container-toolkit libnvidia-container-tools libnvidia-container1
    # Docker Engine oficial
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    # Herramientas del sistema y utilidades CLI
    zsh tmux git btop fastfetch iotop sysstat
    tree eza bat fzf ripgrep fd-find
    nmap traceroute mtr dnsutils tcpdump iperf3 jq
)

echo "--> Desinstalando paquetes de la estación de trabajo..."
apt-get remove -y "${PACKAGES_TO_REMOVE[@]}" || true

# 3. Limpiar repositorios externos y llaves GPG (Docker y NVIDIA)
echo "--> Eliminando fuentes y llaves de APT añadidas..."
rm -f /etc/apt/sources.list.d/docker.list
rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list
rm -f /etc/apt/keyrings/docker.asc
rm -f /etc/apt/keyrings/nvidia-container-toolkit.asc
rm -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
rm -f /etc/apt/sources.list.d/github-cli.list
rm -f /etc/apt/keyrings/githubcli-archive-keyring.gpg

# 4. Eliminar binarios directos, servicios y datos de Ollama
echo "--> Purgando binarios y datos de Ollama..."
rm -f /usr/local/bin/ollama
rm -f /etc/systemd/system/ollama.service
systemctl daemon-reload
rm -rf /usr/share/ollama
userdel -r ollama 2>/dev/null || true
groupdel ollama 2>/dev/null || true

# 5. Eliminar binarios externos y enlaces simbólicos creados
rm -f /usr/local/bin/starship
rm -f /usr/local/bin/bat
rm -f /usr/local/bin/fd

# 6. Eliminar archivo de estado de decisiones (GPU / Ollama)
if [[ -f "$STATE_FILE" ]]; then
    echo "--> Eliminando archivo de estado: $STATE_FILE"
    rm -f "$STATE_FILE"
fi

# 7. Restaurar shell por defecto a Bash
echo "--> Restaurando shell por defecto a Bash..."
chsh -s /bin/bash "$TARGET_USER"

# 8. Limpiar dotfiles y configuraciones del usuario
echo "--> Limpiando dotfiles en $TARGET_HOME..."
rm -rf "$TARGET_HOME/.oh-my-zsh"
rm -f  "$TARGET_HOME/.zshrc" "$TARGET_HOME/.zsh_history"
rm -rf "$TARGET_HOME/.config/starship.toml" "$TARGET_HOME/.config/btop"
rm -rf "$TARGET_HOME/.ollama"
rm -f "$TARGET_HOME/.gitconfig"
rm -rf "$TARGET_HOME/.config/gh"

echo "==> Sistema reseteado con éxito."
