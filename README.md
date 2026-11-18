# CMS for Linux – instalador rápido

Instala Docker (con las versiones recomendadas por el fabricante) y CMS con un solo comando.

**Requisitos:** Ubuntu 24.04 (Noble) de 64 bits, x86_64/amd64, con acceso a internet.

## 1. Verificar el servidor

```bash
git clone https://github.com/pipetelecom/CMS_Cdata.git
cd CMS_Cdata
sudo bash verificar.sh            # revisa todo y busca las versiones de CMS disponibles
sudo bash verificar.sh 1.2.3      # o comprueba una versión concreta
```

Corrige lo que salga marcado con ✘.

## 2. Instalar

```bash
sudo bash instalar.sh <version_cms>   # usa la versión que mostró verificar.sh
```

CMS queda en `/opt/cms`. Si lo quieres en otra carpeta:

```bash
sudo CMS_DIR=/ruta/que/quieras ./instalar.sh <version_cms>
```

## Administrar

| Acción | Comando |
|---|---|
| Iniciar | `cd /opt/cms && sudo docker compose up -d` |
| Detener | `cd /opt/cms && sudo docker compose stop` |
| Reiniciar | `cd /opt/cms && sudo docker compose restart` |
| Actualizar | `cd /opt/cms && sudo ./cms_install.sh upgrade --version <version>` |
| Desinstalar | `cd /opt/cms && sudo docker compose down && sudo rm -rf docker-compose.yml .env` |

## Respaldos

```bash
sudo /opt/cms/cms.sh backup run --path=/ruta/backup                     # manual
sudo /opt/cms/cms.sh backup enable --path=/ruta/backup --frequency=day --file-limit=10  # automático (day/week/month)
sudo /opt/cms/cms.sh backup disable
sudo /opt/cms/cms.sh backup status
sudo /opt/cms/cms.sh restore run --path=/ruta/archivo_backup
```

## Configuración

Cambiar el host de CMS (luego reinicia CMS):

```bash
sudo docker exec -it cms-mysql sh -c 'mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" ccssx_boot -e "update sys_tenant set ip = \"<host>\" "'
```

Restablecer la contraseña de root:

```bash
sudo docker exec -it cms-mysql sh -c 'mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" ccssx_boot -e "source /reset_pwd/reset_pwd.sql"' \
 && sudo docker exec -it cms-redis sh -c 'redis-cli -a cms123 -r 1 del 100000:user_details::root'
```

> La ubicación exacta de `cms.sh` depende del instalador oficial; si no está en `/opt/cms`, búscala con `sudo find / -name cms.sh 2>/dev/null`.
