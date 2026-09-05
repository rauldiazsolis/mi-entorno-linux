#!/usr/bin/env bash
# ==============================================================================
# portainer.sh - Despliegue desatendido de Portainer CE con credenciales autogeneradas
# ==============================================================================
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=../common.sh
source "${SCRIPT_DIR}/../common.sh"

check_root
load_state

ACTION="${1:-install}"
PORTAINER_CRED_DIR="${TARGET_HOME}/.config/portainer"
CRED_FILE="${PORTAINER_CRED_DIR}/credentials.txt"

install_portainer() {
    log_info "Verificando prerrequisitos para Portainer CE..."
    require_state "MODULE_DOCKER" "installed" "docker.sh"

    # 1. Preparar directorio de credenciales seguro
    mkdir -p "$PORTAINER_CRED_DIR"
    chown -R "${TARGET_USER}:${TARGET_USER}" "$PORTAINER_CRED_DIR"
    chmod 700 "$PORTAINER_CRED_DIR"

    # 2. Generar o recuperar contraseña
    local admin_pass=""
    if [[ -f "$CRED_FILE" ]]; then
        admin_pass=$(grep "^PASSWORD=" "$CRED_FILE" | cut -d '=' -f2-)
    fi

    if [[ -z "$admin_pass" ]]; then
        # Generar contraseña segura de 24 caracteres alfanuméricos
        admin_pass=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24)
        cat <<EOF > "$CRED_FILE"
URL=https://localhost:9443
USER=admin
PASSWORD=${admin_pass}
EOF
        chown "${TARGET_USER}:${TARGET_USER}" "$CRED_FILE"
        chmod 600 "$CRED_FILE"
    fi

    # 3. Preparar archivo de contraseña temporal para Portainer
    local pass_tmp="/tmp/portainer_init_pass"
    echo -n "$admin_pass" > "$pass_tmp"
    chmod 600 "$pass_tmp"

    # 4. Remover contenedor y volumen previo si existiera para garantizar primer inicio limpio
    if docker ps -a --format '{{.Names}}' | grep -Eq "^portainer$"; then
        log_info "Removiendo instancia previa de Portainer..."
        docker stop portainer &>/dev/null || true
        docker rm portainer &>/dev/null || true
    fi

    # Si se desea regenerar desde cero el volumen para aplicar la contraseña automática
    docker volume rm portainer_data &>/dev/null || true
    docker volume create portainer_data &>/dev/null

    log_info "Desplegando contenedor Portainer CE con credenciales automáticas..."
    docker run -d \
        --name portainer \
        --restart=always \
        -p 127.0.0.1:9443:9443 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        -v "${pass_tmp}:/tmp/portainer_init_pass:ro" \
        portainer/portainer-ce:latest \
        --admin-password-file=/tmp/portainer_init_pass

    # Limpiar archivo temporal
    rm -f "$pass_tmp"

    set_state_var "MODULE_PORTAINER" "installed"
    log_success "Portainer CE instalado y configurado con éxito."
    echo "--------------------------------------------------------"
    echo " Acceso: https://localhost:9443"
    echo " Usuario: admin"
    echo " Contraseña guardada en: $CRED_FILE"
    echo "--------------------------------------------------------"
}

remove_portainer() {
    log_info "Desinstalando Portainer CE..."
    docker stop portainer &>/dev/null || true
    docker rm portainer &>/dev/null || true
    docker volume rm portainer_data &>/dev/null || true
    rm -rf "$PORTAINER_CRED_DIR"

    unset_state_var "MODULE_PORTAINER"
    log_success "Portainer CE eliminado por completo."
}

case "$ACTION" in
    install)          install_portainer ;;
    remove|uninstall) remove_portainer ;;
    *)
        log_error "Acción no válida: '$ACTION'. Usa 'install' o 'remove'."
        exit 1
        ;;
esac
