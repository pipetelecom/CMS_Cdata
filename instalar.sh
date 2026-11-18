#!/usr/bin/env bash
# Instalador de CMS for Linux en un solo paso.
# Uso:   sudo ./instalar.sh <version_cms>
# Ej.:   sudo ./instalar.sh 1.2.3
# Requiere Ubuntu 24.04 (Noble) de 64 bits (x86_64 / amd64).

set -euo pipefail

CMS_VERSION="${1:-}"
CMS_DIR="${CMS_DIR:-/opt/cms}"
SCRIPT_URL="https://cms.s.cdatayun.com/cms_linux/cms_install.sh"

# Versiones de Docker recomendadas por el manual de CMS
CONTAINERD_VER="1.7.23-1"
DOCKER_VER="5:27.3.1-1~ubuntu.24.04~noble"
BUILDX_VER="0.17.1-1~ubuntu.24.04~noble"
COMPOSE_VER="2.29.7-1~ubuntu.24.04~noble"

info()  { echo -e "\e[32m[CMS]\e[0m $*"; }
error() { echo -e "\e[31m[ERROR]\e[0m $*" >&2; exit 1; }

# ---------- Comprobaciones ----------
[[ $EUID -eq 0 ]] || error "Ejecuta con sudo:  sudo ./instalar.sh <version_cms>"
[[ -n "$CMS_VERSION" ]] || error "Falta la versión de CMS.  Uso: sudo ./instalar.sh <version_cms>"
[[ "$(uname -m)" == "x86_64" ]] || error "CMS solo funciona en x86_64 (amd64)."

. /etc/os-release
[[ "${ID:-}" == "ubuntu" && "${VERSION_CODENAME:-}" == "noble" ]] \
  || error "Se requiere Ubuntu 24.04 (Noble). Detectado: ${PRETTY_NAME:-desconocido}"

# ---------- Docker ----------
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  info "Docker ya está instalado: $(docker --version)"
else
  info "Quitando paquetes de Docker de Ubuntu que chocan con el oficial..."
  apt-get remove -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc 2>/dev/null || true
  dpkg --configure -a || true
  info "Instalando Docker (versiones recomendadas por CMS)..."
  apt-get update -y
  apt-get install -y ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y --allow-downgrades \
    containerd.io="$CONTAINERD_VER" \
    docker-ce="$DOCKER_VER" \
    docker-ce-cli="$DOCKER_VER" \
    docker-buildx-plugin="$BUILDX_VER" \
    docker-compose-plugin="$COMPOSE_VER"
  # Evita que apt actualice Docker a una versión no probada con CMS
  apt-mark hold containerd.io docker-ce docker-ce-cli docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
fi

docker compose version >/dev/null 2>&1 \
  || error "Docker Compose no quedó instalado. Corre: sudo apt-get install -y docker-compose-plugin=$COMPOSE_VER"

# ---------- CMS ----------
CODE=$(curl -s -o /dev/null -m 15 -w '%{http_code}' -I \
  "https://cms.s.cdatayun.com/cms_linux/stable/cms_v${CMS_VERSION}_linux.tar")
[[ "$CODE" == "200" ]] || error "La versión $CMS_VERSION no existe en el servidor de CData (código $CODE). Corre 'sudo bash verificar.sh' para ver las disponibles."
info "Preparando carpeta $CMS_DIR"
mkdir -p "$CMS_DIR"
cd "$CMS_DIR"

info "Descargando script oficial de CMS..."
curl -fsSL -o cms_install.sh "$SCRIPT_URL"
chmod +x cms_install.sh

info "Instalando CMS versión $CMS_VERSION ..."
./cms_install.sh install --version "$CMS_VERSION"

info "Listo. CMS quedó instalado en $CMS_DIR"
info "Comandos útiles:"
echo "  Iniciar:    cd $CMS_DIR && sudo docker compose up -d"
echo "  Detener:    cd $CMS_DIR && sudo docker compose stop"
echo "  Reiniciar:  cd $CMS_DIR && sudo docker compose restart"
echo "  Actualizar: cd $CMS_DIR && sudo ./cms_install.sh upgrade --version <nueva_version>"
