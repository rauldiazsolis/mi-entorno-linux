# 📦 Automatización de Entornos de Desarrollo Agnósticos (Ubuntu / Mint)

Este repositorio contiene scripts dinámicos y modulares para aprovisionar estaciones de trabajo Linux orientadas al desarrollo en contenedores (**Dev Containers**). Su diseño evita la contaminación del sistema anfitrión con runtimes (Node.js, Python, etc.), garantiza la reproducibilidad y es completamente **independiente de la arquitectura de hardware** (x86_64 y ARM64).

---

## 🛠️ 1. Matriz de Simetría de Software e IDEs

El entorno prioriza el aislamiento de dependencias. Las herramientas se configuran a nivel de sistema o IDE respetando la siguiente distribución:

| Componente / Extensión | Visual Studio Code | Google Antigravity IDE | Ámbito / Tipo |
| :--- | :---: | :---: | :--- |
| **Docker Engine CE** | N/A | N/A | Motor nativo con socket para usuario sin `sudo` |
| **Portainer CE** | N/A | N/A | GUI web local en `127.0.0.1:9443` (credenciales autogeneradas) |
| **Google Antigravity IDE** | N/A | Host | Suite nativa v2.5.5 Standalone con soporte Gemini 3.7 |
| `google.google-antigravity` | ✅ Sí | ✅ Sí | Extensión oficial de agente IA |
| `crsx.ag-usage` | ❌ No | ✅ Sí | Telemetría y monitoreo de cuota de modelos |
| `ms-azuretools.vscode-docker` | ✅ Sí | ✅ Sí | Inspección visual de contenedores, redes e imágenes |
| `mermaidchart.vscode-mermaid-chart`| ✅ Sí | ✅ Sí | Diagramación y documentación técnica |
| `dbaeumer.vscode-eslint` | ✅ Sí | ✅ Sí | Linter local / base |
| `esbenp.prettier-vscode` | ✅ Sí | ✅ Sí | Formateador de código |
| **Dev Containers** | ✅ Extensión | ✅ Nativo integrado | Entorno aislado por proyecto (`.devcontainer.json`) |

> **Aislamiento en contenedores:** Las herramientas de ejecución e inspección en vivo de cada proyecto (Node, ESLint de proyecto, npm) residen exclusivamente dentro de su respectivo Dev Container, asegurando que el host permanezca limpio e inalterado.

---

## 🕵️ 2. Lógica de Adaptación de Hardware (Notas de Arquitectura)

Los scripts están diseñados para operar de forma transparente en múltiples arquitecturas y plataformas de hardware:

* **Arquitectura de Procesador (x86_64 vs ARM64):** Los módulos de repositorios APT consultan `dpkg --print-architecture`, mientras que las descargas de binarios independientes (`antigravity.sh`) resuelven dinámicamente el tarball correspondiente (`linux-x64` o `linux-arm`) mediante `uname -m`.
* **Detección Dinámica de GPU:** El script consulta el bus PCI (`lspci`). Si detecta hardware gráfico NVIDIA, orquesta la instalación de los controladores oficiales y el `nvidia-container-toolkit` para habilitar aceleración por hardware en Docker sin intervención manual.
* **Seguridad en Dev Containers:** Los contenedores se ejecutan bajo directivas `--security-opt=no-new-privileges:true` y montan volúmenes con permisos del usuario no privilegiado (`remoteUser: node`).

---

## 📂 3. Estructura del Repositorio

```text
mi-entorno-linux/
├── bootstrap.sh                 # Punto de entrada universal (soporta curl/wget remoto)
└── ubuntu/
    ├── common.sh                # Variables comunes, control de estado y logging
    ├── install.sh               # Orquestador integral e idempotente
    ├── reset.sh                 # Desinstalador ordenado (reversa de dependencias)
    └── modules/
        ├── core.sh              # Paquetes base esenciales y dependencias de sistema
        ├── gpu.sh               # Detección NVIDIA y configuración de toolkit de GPU
        ├── git.sh               # Git, configuración de usuario y GitHub CLI (gh)
        ├── docker.sh            # Docker CE, docker-compose-plugin y grupo docker
        ├── vscode.sh            # Visual Studio Code y extensiones de desarrollo
        ├── antigravity.sh       # Antigravity IDE 2.5.5 Standalone y accesos de escritorio
        └── portainer.sh         # Portainer CE local con hardening de credenciales

```

---

## 🚀 4. Guía de Ejecución Rápida

Para desplegar el entorno completo en una instalación limpia de Ubuntu o en una sesión Live:

### Despliegue Automatizado (Recomendado)

Ejecución directa en una sola línea mediante `curl`:

```bash
curl -fsSL [https://raw.githubusercontent.com/rauldiazsolis/mi-entorno-linux/main/bootstrap.sh](https://raw.githubusercontent.com/rauldiazsolis/mi-entorno-linux/main/bootstrap.sh) | sudo bash

```

o mediante `wget`:

```bash
wget -qO- [https://raw.githubusercontent.com/rauldiazsolis/mi-entorno-linux/main/bootstrap.sh](https://raw.githubusercontent.com/rauldiazsolis/mi-entorno-linux/main/bootstrap.sh) | sudo bash

```

### Ejecución Local

Si ya has clonado el repositorio:

```bash
git clone [https://github.com/rauldiazsolis/mi-entorno-linux.git](https://github.com/rauldiazsolis/mi-entorno-linux.git)
cd mi-entorno-linux

# 1. Despliegue integral
sudo ./bootstrap.sh install

# 2. Despliegue de un módulo puntual (ejemplo: Antigravity IDE)
sudo ./bootstrap.sh modules/antigravity.sh install

# 3. Reversión completa del entorno
sudo ./bootstrap.sh reset

```

---

## 🔐 5. Gestión de Portainer CE

Por motivos de seguridad, Portainer se vincula exclusivamente a la interfaz local (`127.0.0.1:9443`). La contraseña de administrador se genera de forma criptográfica durante el despliegue para evitar bloqueos por tiempo de espera.

* **URL de Acceso:** [https://localhost:9443](https://localhost:9443)
* **Usuario:** `admin`
* **Consulta de Credenciales:**
```bash
cat ~/.config/portainer/credentials.txt

```
