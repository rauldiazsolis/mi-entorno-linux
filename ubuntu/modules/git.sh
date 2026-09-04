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

# 3. Autenticación asistida con portapapeles y navegador
    if ! gh auth status &>/dev/null; then
        log_warn "Iniciando vinculación con GitHub..."

        # Asegurar xclip para el portapapeles
        if ! command -v xclip &>/dev/null; then
            sudo apt-get install -y --no-install-recommends xclip &>/dev/null || true
        fi

        # Client ID oficial de GitHub CLI para Device Flow
        local client_id="178c6fc778aca681fa96"
        local response
        response=$(curl -s -X POST https://github.com/login/device/code \
            -H "Accept: application/json" \
            -d "client_id=${client_id}&scope=repo,read:org,read:user,user:email")

        local device_code user_code verification_uri interval
        device_code=$(echo "$response" | jq -r '.device_code')
        user_code=$(echo "$response" | jq -r '.user_code')
        verification_uri=$(echo "$response" | jq -r '.verification_uri // "https://github.com/login/device"')
        interval=$(echo "$response" | jq -r '.interval // 5')

        if [[ -z "$user_code" || "$user_code" == "null" ]]; then
            log_error "No se pudo obtener el código de activación de GitHub. Comprueba tu conexión."
            exit 1
        fi

        # Copiar código al portapapeles automáticamente
        echo -n "$user_code" | xclip -selection clipboard 2>/dev/null || true

        echo ""
        echo "============================================================"
        echo -e " Código de activación: \e[1;32m${user_code}\e[0m (¡Copiado al portapapeles!)"
        echo "============================================================"
        echo "--> Abriendo ${verification_uri} en Firefox..."
        echo "--> Simplemente presiona Ctrl + V en la página y haz clic en Continuar."
        echo ""

        xdg-open "$verification_uri" &>/dev/null &

        # Esperar autorización en segundo plano
        log_info "Esperando autorización en el navegador..."
        local token=""
        while true; do
            sleep "$interval"
            local poll_resp
            poll_resp=$(curl -s -X POST https://github.com/login/oauth/access_token \
                -H "Accept: application/json" \
                -d "client_id=${client_id}&device_code=${device_code}&grant_type=urn:ietf:params:oauth:grant-type:device_code")

            local error
            error=$(echo "$poll_resp" | jq -r '.error // empty')

            if [[ "$error" == "authorization_pending" ]]; then
                continue
            elif [[ "$error" == "slow_down" ]]; then
                interval=$((interval + 5))
                continue
            elif [[ -n "$error" ]]; then
                log_error "Error en la autorización de GitHub: $error"
                break
            fi

            token=$(echo "$poll_resp" | jq -r '.access_token // empty')
            if [[ -n "$token" ]]; then
                break
            fi
        done

        if [[ -n "$token" ]]; then
            echo "$token" | gh auth login --with-token
            gh config set -h github.com git_protocol https
            log_success "Autenticación en GitHub completada con éxito."
        fi
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
