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

    # Validación directa contra el daemon de Docker
    if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
        log_error "Docker no parece estar corriendo o instalado. Ejecuta docker.sh primero."
        exit 1
    fi

    # 1. Preparar directorio seguro para guardar las credenciales
    mkdir -p "$PORTAINER_CRED_DIR"
    chmod 700 "$PORTAINER_CRED_DIR"
    chown -R "${TARGET_USER}:${TARGET_USER}" "$PORTAINER_CRED_DIR"

    # 2. Generar o recuperar contraseña
    local admin_pass=""
    if [[ -f "$CRED_FILE" ]]; then
        admin_pass=$(grep "^PASSWORD=" "$CRED_FILE" | cut -d '=' -f2-)
    fi

    if [[ -z "$admin_pass" ]]; then
        admin_pass=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24)
        cat <<EOF > "$CRED_FILE"
URL=https://localhost:9443
USER=admin
PASSWORD=${admin_pass}
EOF
        chmod 600 "$CRED_FILE"
        chown "${TARGET_USER}:${TARGET_USER}" "$CRED_FILE"
    fi

    # 3. Limpiar cualquier contenedor y volumen previo para forzar inicio limpio
    log_info "Limpiando instancias anteriores de Portainer..."
    docker stop portainer &>/dev/null || true
    docker rm portainer &>/dev/null || true
    docker volume rm portainer_data &>/dev/null || true
    docker volume create portainer_data &>/dev/null

    # 4. Generar hash bcrypt para Portainer
    # Portainer acepta la contraseña hasheada directamente con --admin-password
    log_info "Desplegando contenedor Portainer CE..."
    local pass_hash
    pass_hash=$(docker run --rm -i httpd:alpine htpasswd -nbB admin "$admin_pass" | cut -d ":" -f 2)

    docker run -d \
        --name portainer \
        --restart=always \
        -p 127.0.0.1:9443:9443 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest \
        --admin-password="$pass_hash"

    set_state_var "MODULE_PORTAINER" "installed"
    log_success "Portainer CE configurado e iniciado."
    echo "========================================================"
    echo " URL:         https://localhost:9443"
    echo " Usuario:     admin"
    echo " Contraseña:  ${admin_pass}"
    echo " Guardada en: ${CRED_FILE}"
    echo "========================================================"
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
