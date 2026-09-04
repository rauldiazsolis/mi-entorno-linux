#!/usr/bin/env bash
# ==============================================================================
# git.sh - GitHub CLI, autenticación e identidad de Git (Espacio de Usuario)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=../common.sh
source "${SCRIPT_DIR}/../common.sh"

load_state

ACTION="${1:-install}"

# Función interna para instalar el paquete gh con privilegios
ensure_gh_installed() {
    if command -v gh &>/dev/null; then
        log_info "GitHub CLI ya está instalado en el sistema."
        return 0
    fi

    log_info "Instalando GitHub CLI (requiere privilegios root)..."
    sudo install -m 0755 -d /etc/apt/keyrings

    if [[ ! -f /etc/apt/keyrings/githubcli-archive-keyring.gpg ]]; then
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
            | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
        sudo chmod 644 /etc/apt/keyrings/githubcli-archive-keyring.gpg
    fi

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y --no-install-recommends gh
    log_success "GitHub CLI instalado correctamente."
}

install_git_identity() {
    log_info "Verificando prerrequisitos para Git..."
    require_state "MODULE_CORE" "installed" "core.sh"

    # 1. Instalar gh si falta (solicita sudo de forma acotada si es necesario)
    ensure_gh_installed

    # 2. Comprobar si ya existe identidad configurada
    local current_user current_email
    current_user=$(git config --global user.name || true)
    current_email=$(git config --global user.email || true)

    if [[ -n "$current_user" && -n "$current_email" ]]; then
        log_info "Identidad de Git ya configurada: $current_user <$current_email>"
        sudo bash -c "source '${SCRIPT_DIR}/../common.sh' && set_state_var MODULE_GIT installed"
        return 0
    fi

    # 3. Flujo asistido oficial mediante gh con copia a clipboard
    if ! gh auth status &>/dev/null; then
        log_warn "Es necesario iniciar sesión en GitHub para extraer tu perfil y correo."

        # Asegurar xclip para soporte de portapapeles
        if ! command -v xclip &>/dev/null; then
            sudo apt-get install -y --no-install-recommends xclip &>/dev/null || true
        fi

        echo ""
        echo "--> Preparando autenticación..."
        echo "--> El navegador se abrirá en https://github.com/login/device."
        echo ""

        # Definir script temporal de apertura que copia el link y levanta el browser
        export BROWSER="xdg-open"

        # Lanzar gh auth login preconfigurado (sin preguntas previas de protocolo)
        # --git-protocol https evita la primera pregunta
        # -w abre el navegador web usando el BROWSER asignado
        gh auth login -h github.com -p https -w -s "read:user,user:email" </dev/tty >/dev/tty 2>&1 || true
    fi

    # 4. Extraer identidad y configurar ~/.gitconfig
    if gh auth status &>/dev/null; then
        local gh_name gh_email
        gh_name=$(gh api user --jq '.name // .login')
        gh_email=$(gh api user/emails --jq '[.[] | select(.primary == true)][0].email // empty')

        if [[ -z "$gh_email" ]]; then
            gh_email=$(gh api user --jq '.email // empty')
        fi

        if [[ -n "$gh_name" ]]; then
            git config --global user.name "$gh_name"
            log_success "user.name configurado: $gh_name"
        fi

        if [[ -n "$gh_email" ]]; then
            git config --global user.email "$gh_email"
            log_success "user.email configurado: $gh_email"
        fi

        gh auth setup-git
        log_success "Helper de credenciales configurado para Git."
    else
        log_warn "Autenticación no completada. Configura Git manualmente con 'git config --global'."
    fi

    sudo bash -c "source '${SCRIPT_DIR}/../common.sh' && set_state_var MODULE_GIT installed"
    log_success "Módulo Git completado y registrado."
}

remove_git_identity() {
    log_info "Solicitada desinstalación del módulo Git / GitHub CLI..."
    prevent_removal_if "MODULE_VSCODE" "vscode.sh"

    log_info "Eliminando paquete gh..."
    sudo apt-get remove -y gh || true
    sudo rm -f /etc/apt/sources.list.d/github-cli.list
    sudo rm -f /etc/apt/keyrings/githubcli-archive-keyring.gpg

    log_info "Limpiando configuración de Git..."
    rm -f "$HOME/.gitconfig"
    rm -rf "$HOME/.config/gh"

    sudo bash -c "source '${SCRIPT_DIR}/../common.sh' && unset_state_var MODULE_GIT"
    log_success "Módulo Git desinstalado y desregistrado con éxito."
}

case "$ACTION" in
    install)          install_git_identity ;;
    remove|uninstall) remove_git_identity ;;
    *)
        log_error "Acción no válida: '$ACTION'. Usa 'install' o 'remove'."
        exit 1
        ;;
esac
