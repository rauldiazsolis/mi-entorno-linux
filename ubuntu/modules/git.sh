#!/usr/bin/env bash
# ==============================================================================
# git.sh - GitHub CLI, autenticación interactiva e identidad de Git
# ==============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=../common.sh
source "${SCRIPT_DIR}/../common.sh"

check_root
load_state

ACTION="${1:-install}"

install_git_identity() {
    log_info "Verificando prerrequisitos para Git y GitHub CLI..."
    require_state "MODULE_CORE" "installed" "core.sh"

    # 1. Instalar GitHub CLI oficial si no está presente
    if command -v gh &>/dev/null; then
        log_info "GitHub CLI ya está instalado. Omitiendo instalación de paquete..."
    else
        log_info "Configurando repositorio oficial de GitHub CLI..."
        install -m 0755 -d /etc/apt/keyrings

        if [[ ! -f /etc/apt/keyrings/githubcli-archive-keyring.gpg ]]; then
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
            chmod 644 /etc/apt/keyrings/githubcli-archive-keyring.gpg
        fi

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
            > /etc/apt/sources.list.d/github-cli.list

        apt-get update -y
        apt-get install -y --no-install-recommends gh
        log_success "GitHub CLI instalado correctamente."
    fi

    # 2. Comprobar si ya existe identidad global configurada
    local current_user current_email
    current_user=$(sudo -u "$TARGET_USER" git config --global user.name || true)
    current_email=$(sudo -u "$TARGET_USER" git config --global user.email || true)

    if [[ -n "$current_user" && -n "$current_email" ]]; then
        log_info "Identidad de Git ya configurada: $current_user <$current_email>"
        set_state_var "MODULE_GIT" "installed"
        return 0
    fi

    # 3. Flujo de autenticación interactivo mediante consola
    if ! sudo -u "$TARGET_USER" gh auth status &>/dev/null; then
        log_warn "Es necesario iniciar sesión en GitHub para extraer tu perfil y correo."
        echo ""
        echo "--> Sigue las instrucciones en pantalla para vincular tu cuenta:"
        sudo -u "$TARGET_USER" gh auth login --hostname github.com --git-protocol https --web --scopes "read:user,user:email" </dev/tty >/dev/tty 2>&1 || true
    fi

    # 4. Extraer datos del perfil autenticado e inyectar en gitconfig
    if sudo -u "$TARGET_USER" gh auth status &>/dev/null; then
        local gh_name gh_email
        gh_name=$(sudo -u "$TARGET_USER" gh api user --jq '.name // .login')
        gh_email=$(sudo -u "$TARGET_USER" gh api user/emails --jq '[.[] | select(.primary == true)][0].email // empty')

        if [[ -z "$gh_email" ]]; then
            gh_email=$(sudo -u "$TARGET_USER" gh api user --jq '.email // empty')
        fi

        if [[ -n "$gh_name" ]]; then
            sudo -u "$TARGET_USER" git config --global user.name "$gh_name"
            log_success "user.name configurado: $gh_name"
        fi

        if [[ -n "$gh_email" ]]; then
            sudo -u "$TARGET_USER" git config --global user.email "$gh_email"
            log_success "user.email configurado: $gh_email"
        fi

        # Helper oficial para no volver a pedir contraseña en git push/pull
        sudo -u "$TARGET_USER" gh auth setup-git
        log_success "Helper de credenciales configurado para Git."
    else
        log_warn "Autenticación omitida o incompleta. Configura Git manualmente con: git config --global"
    fi

    set_state_var "MODULE_GIT" "installed"
    log_success "Módulo Git completado y registrado."
}

remove_git_identity() {
    log_info "Solicitada desinstalación del módulo Git / GitHub CLI..."

    prevent_removal_if "MODULE_VSCODE" "vscode.sh"

    log_info "Eliminando paquete gh y configuración de repositorio..."
    apt-get remove -y gh || true
    rm -f /etc/apt/sources.list.d/github-cli.list
    rm -f /etc/apt/keyrings/githubcli-archive-keyring.gpg

    log_info "Limpiando credenciales y configuración global de Git..."
    rm -f "$TARGET_HOME/.gitconfig"
    rm -rf "$TARGET_HOME/.config/gh"

    unset_state_var "MODULE_GIT"
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
