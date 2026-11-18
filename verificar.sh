#!/usr/bin/env bash
# Verifica que el servidor esté listo para desplegar CMS for Linux.
# Uso:  sudo bash verificar.sh [version_cms]
# Si no das versión, busca automáticamente las versiones disponibles.

CMS_VER="${1:-}"
BASE="https://cms.s.cdatayun.com/cms_linux"
OK=0; FALLO=0
ok()    { echo -e "  \e[32m✔\e[0m $*"; OK=$((OK+1)); }
fallo() { echo -e "  \e[31m✘\e[0m $*"; FALLO=$((FALLO+1)); }
aviso() { echo -e "  \e[33m!\e[0m $*"; }
titulo(){ echo -e "\n\e[1m$*\e[0m"; }

titulo "1. Sistema"
. /etc/os-release
[[ "$ID" == "ubuntu" && "$VERSION_CODENAME" == "noble" ]] \
  && ok "Ubuntu 24.04 ($PRETTY_NAME)" || fallo "Se requiere Ubuntu 24.04 Noble (tienes: $PRETTY_NAME)"
[[ "$(uname -m)" == "x86_64" ]] && ok "Arquitectura x86_64" || fallo "Arquitectura $(uname -m) no soportada"
[[ $EUID -eq 0 ]] && ok "Ejecutando como root" || aviso "Ejecuta con sudo para revisar todo"
LIBRE=$(df -BG --output=avail / | tail -1 | tr -dc 0-9)
(( LIBRE >= 20 )) && ok "Espacio libre en disco: ${LIBRE} GB" || fallo "Poco espacio en disco: ${LIBRE} GB (recomendado ≥ 20 GB)"
RAM=$(free -g | awk '/Mem:/{print $2}')
(( RAM >= 4 )) && ok "RAM: ${RAM} GB" || aviso "RAM: ${RAM} GB (recomendado ≥ 4 GB)"

titulo "2. Internet y repositorios"
for url in https://download.docker.com/linux/ubuntu/dists/noble/Release \
           https://registry-1.docker.io/v2/ \
           "$BASE/cms_install.sh"; do
  code=$(curl -s -o /dev/null -m 15 -w '%{http_code}' "$url")
  [[ "$code" =~ ^(200|401)$ ]] && ok "Accesible: $url" || fallo "Sin acceso ($code): $url"
done

titulo "3. Docker"
for p in docker.io docker-compose-v2 docker-compose podman-docker containerd runc; do
  dpkg -s "$p" >/dev/null 2>&1 && fallo "Paquete en conflicto instalado: $p (quítalo con: sudo apt-get remove -y $p)"
done
if command -v docker >/dev/null; then
  ok "$(docker --version)"
  docker compose version >/dev/null 2>&1 && ok "$(docker compose version)" || fallo "Falta docker compose (docker-compose-plugin)"
  systemctl is-active --quiet docker 2>/dev/null && ok "Servicio docker activo" || fallo "Servicio docker detenido (sudo systemctl start docker)"
  docker run --rm hello-world >/dev/null 2>&1 && ok "Docker puede descargar y correr contenedores" \
    || fallo "Docker no pudo correr hello-world"
else
  aviso "Docker no está instalado (instalar.sh lo instala)"
  apt-cache madison docker-ce 2>/dev/null | grep -q "27.3.1-1~ubuntu.24.04~noble" \
    && ok "Versión recomendada docker-ce 27.3.1 disponible en apt" \
    || aviso "No se ve docker-ce 27.3.1 en apt (normal si aún no se agregó el repo de Docker)"
fi
dpkg --audit 2>/dev/null | grep -q . && fallo "apt/dpkg tiene paquetes a medio instalar (sudo dpkg --configure -a)" || ok "apt/dpkg sin errores pendientes"

titulo "4. Versión de CMS"
existe() { [[ "$(curl -s -o /dev/null -m 10 -w '%{http_code}' -I "$BASE/stable/cms_v$1_linux.tar")" == "200" ]]; }
if [[ -n "$CMS_VER" ]]; then
  existe "$CMS_VER" && ok "La versión $CMS_VER existe y se puede descargar" \
    || fallo "La versión $CMS_VER NO existe en el servidor de CData"
else
  echo "  Buscando versiones disponibles (1.0.0 – 3.9.9), espera un momento..."
  ENCONTRADAS=()
  for a in 1 2 3; do for b in $(seq 0 9); do for c in $(seq 0 9); do
    existe "$a.$b.$c" && ENCONTRADAS+=("$a.$b.$c")
  done; done; done
  if (( ${#ENCONTRADAS[@]} )); then
    ok "Versiones disponibles: ${ENCONTRADAS[*]}"
    echo "     Instala la más reciente:  sudo bash instalar.sh ${ENCONTRADAS[-1]}"
  else
    fallo "No se encontró ninguna versión con formato X.Y.Z; pide el número exacto a CData"
  fi
fi

titulo "5. Puertos"
EN_USO=$(ss -tlnH | awk '{print $4}' | grep -oE '[0-9]+$' | sort -un | tr '\n' ' ')
[[ -n "$EN_USO" ]] && aviso "Puertos ya ocupados en el servidor: $EN_USO (CMS no debe chocar con ellos)" || ok "No hay puertos ocupados"

echo -e "\n\e[1mResultado: $OK correctos, $FALLO con problema\e[0m"
(( FALLO == 0 )) && echo -e "\e[32mEl servidor está listo para desplegar CMS.\e[0m" \
                 || echo -e "\e[31mCorrige los puntos marcados con ✘ antes de instalar.\e[0m"
exit $FALLO
