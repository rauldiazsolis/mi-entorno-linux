# 📦 Automatización de Entornos de Desarrollo Agnósticos (Ubuntu / Mint)

Este repositorio contiene scripts dinámicos y autogestionados para desplegar entornos de desarrollo profesional minimalistas. El diseño de este código es estrictamente **agnóstico al hardware fijo** e implementa lógica adaptativa en tiempo real.

---

## 🛠️ 1. Matriz de Simetría de Software e IDEs

El entorno se rige por un principio de minimalismo absoluto. Las herramientas se configuran de forma global respetando el siguiente mapa:

| Componente / Extensión              | Visual Studio Code | Google Antigravity IDE | Ámbito / Tipo                                               |
| :---------------------------------- | :----------------: | :--------------------: | :---------------------------------------------------------- |
| **Google Chrome**                   |        N/A         |          N/A           | Global (Instalación nativa .deb)                            |
| **Docker Engine**                   |        N/A         |          N/A           | Global (Motor nativo sin interfaz de escritorio)            |
| **Portainer CE**                    |        N/A         |          N/A           | Contenedor global en puerto `:9000` con reinicio automático |
| **Ollama**                          |        N/A         |          N/A           | Servicio global de IA local (Adaptativo a GPU/CPU)          |
| `continue.continue`                 |       ✅ Sí        |         ❌ No          | Extensión exclusiva de IA                                   |
| `crsx.ag-usage`                     |       ❌ No        |         ✅ Sí          | Extensión exclusiva de telemetría interna                   |
| `dbaeumer.vscode-eslint`            |       ✅ Sí        |         ✅ Sí          | Extensión compartida (Sintaxis)                             |
| `esbenp.prettier-vscode`            |       ✅ Sí        |         ✅ Sí          | Extensión compartida (Formato)                              |
| `ms-azuretools.vscode-docker`       |       ✅ Sí        |         ✅ Sí          | Extensión compartida (Gestión Docker)                       |
| `ms-azuretools.vscode-containers`   |       ✅ Sí        |         ✅ Sí          | Extensión compartida (Devcontainers)                        |
| `mermaidchart.vscode-mermaid-chart` |       ✅ Sí        |         ✅ Sí          | Extensión compartida (Diagramas)                            |

---

## 🕵️ 2. Lógica de Adaptación de Hardware (Notas para la IA)

Los scripts de este repositorio **no deben parametrizarse con datos fijos de componentes** (como marcas o modelos específicos de GPUs o procesadores). En su lugar, el script ejecuta una detección automatizada en caliente:

- **Detección de Gráficos:** Utiliza consultas al bus PCI (`lspci`). Si se identifica una arquitectura NVIDIA, el flujo altera la secuencia de instalación para inyectar los drivers propietarios del kernel y el `nvidia-container-toolkit` de Docker de forma transparente.
- **Periféricos estándar:** El audio, bluetooth y red se delegan por completo al subsistema de drivers nativos del Kernel de Linux (Plug & Play).

---

## 📂 3. Estructura del Repositorio

- `/ubuntu`: Scripts optimizados para sistemas con entorno gráfico GNOME.
- `/mint`: Scripts optimizados para sistemas con entorno Cinnamon.

---

## 🚀 4. Guía de Ejecución Rápida (Sistemas en Inglés)

Para desplegar el entorno en una instalación limpia o en el **Modo Live (Pruebas)**, abre la terminal y ejecuta:

### Opción A: Despliegue en Ubuntu

```bash
cd ~/Downloads && curl -L "https://githubusercontent.com/rauldiazsolis/mi-entorno-linux/main/ubuntu/instalar.sh" -o instalar.sh && chmod +x instalar.sh && ./instalar.sh
```

### Opción B: Despliegue en Linux Mint

```bash
cd ~/Downloads && curl -L "https://githubusercontent.com/rauldiazsolis/mi-entorno-linux/main/mint/instalar.sh" -o instalar.sh && chmod +x instalar.sh && ./instalar.sh
```
