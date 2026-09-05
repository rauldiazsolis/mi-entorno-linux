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

    if ! command -v docker >/dev/null 2>&1; then
        log_error "El binario 'docker' no está en el PATH. Ejecuta docker.sh primero."
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        log_error "El daemon de Docker no responde. Verifica que el servicio esté activo."
        exit 1
    fi

    # 1. Preparar directorio seguro para credenciales
    mkdir -p "$PORTAINER_CRED_DIR"
    chmod 700 "$PORTAINER_CRED_DIR"
    chown -R "${TARGET_USER}:${TARGET_USER}" "$PORTAINER_CRED_DIR"

    # 2. Generar o recuperar contraseña
    local admin_pass=""
    if [[ -f "$CRED_FILE" ]]; then
        admin_pass=$(grep "^PASSWORD=" "$CRED_FILE" | cut -d '=' -f2- || true)
    fi

    if [[ -z "$admin_pass" ]]; then
        # Generación a prueba de SIGPIPE/pipefail usando openssl
        admin_pass=$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' || true)
        if [[ -z "$admin_pass" ]]; then
            admin_pass=$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20 || true)
        fi

        cat <<EOF > "$CRED_FILE"
URL=https://localhost:9443
USER=admin
PASSWORD=${admin_pass}
EOF
        chmod 600 "$CRED_FILE"
        chown "${TARGET_USER}:${TARGET_USER}" "$CRED_FILE"
    fi

    # 3. Limpiar instancias previas
    log_info "Limpiando instancias anteriores de Portainer..."
    docker stop portainer >/dev/null 2>&1 || true
    docker rm portainer >/dev/null 2>&1 || true
    docker volume rm portainer_data >/dev/null 2>&1 || true
    docker volume create portainer_data >/dev/null 2>&1

    # 4. Generar hash bcrypt y levantar Portainer
    log_info "Generando hash seguro de contraseña..."
    local pass_hash
    pass_hash=$(docker run --rm -i httpd:alpine htpasswd -nbB admin "$admin_pass" | cut -d ":" -f 2)

    log_info "Iniciando contenedor Portainer CE..."
    docker run -d \
        --name portainer \
        --restart=always \
        -p 127.0.0.1:9443:9443 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest \
        --admin-password="$pass_hash"

    set_state_var "MODULE_PORTAINER" "installed"
    log_success "Portainer CE configurado e iniciado con éxito."
    echo "========================================================"
    echo " URL:         https://localhost:9443"
    echo " Usuario:     admin"
    echo " Contraseña:  ${admin_pass}"
    echo " Guardada en: ${CRED_FILE}"
    echo "========================================================"
}

remove_portainer() {
    log_info "Desinstalando Portainer CE..."
    docker stop portainer >/dev/null 2>&1 || true
    docker rm portainer >/dev/null 2>&1 || true
    docker volume rm portainer_data >/dev/null 2>&1 || true
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
