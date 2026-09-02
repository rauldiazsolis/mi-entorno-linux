#!/bin/bash

# =====================================================================
# RASTREADOR DE ERRORES DINÁMICO (Manejo de fallos por línea)
# =====================================================================
failure_handler() {
    local line_no=$1
    local exit_code=$2
    local last_command=$3
    echo ""
    echo "===================================================="
    echo "❌ ERROR DETECTADO - EL SCRIPT SE DETUVO"
    echo "===================================================="
    echo "📍 Línea del fallo: $line_no"
    echo "💻 Último comando ejecutado: '$last_command'"
    echo "🛑 Código de salida: $exit_code"
    echo "----------------------------------------------------"
    echo "💡 TIP: Puedes ejecutar './limpiar.sh' para limpiar"
    echo "   el sistema y volver a intentar la ejecución."
    echo "===================================================="
    exit "$exit_code"
}

# Activar el rastreo estricto de errores
set -e
trap 'failure_handler ${LINENO} $? "$BASH_COMMAND"' ERR

echo "===================================================="
echo "      ASISTENTE DE CONFIGURACIÓN AUTOMÁTICA          "
echo "===================================================="
echo ""

# Actualizar repositorios iniciales e instalar dependencias básicas de diagnóstico
sudo apt update && sudo apt install -y pciutils curl git

echo ""
echo "🕵️  Detectando especificaciones de hardware en tiempo real..."
HAS_NVIDIA=false
if lspci | grep -iq nvidia; then
    HAS_NVIDIA=true
    echo "   -> [Hardware]: Se ha detectado una GPU NVIDIA activa."
else
    echo "   -> [Hardware]: Usando gráficos genéricos / integrados."
fi
echo "===================================================="
echo ""
