#!/bin/bash
set -e

#evtl noch den dump selbst erstellen?
#sudo mysqldump -u root -p moodle > dump.sql

#vielleiht auch noh einfach config und dump ins /tmp/migration machen.

MOODLEDATA=/tmp/moodledata
mkdir -p $MOODLEDATA
chmod 777 $MOODLEDATA

docker network create fadenet_migration 2>/dev/null || true

docker rm -f mariadb_migration 2>/dev/null || true
docker run -d --name mariadb_migration --network fadenet_migration \
  -e MARIADB_ROOT_PASSWORD=1 \
  -e MARIADB_DATABASE=fade_db \
  -e MARIADB_USER=fade_user \
  -e MARIADB_PASSWORD=fade_pw \
  mariadb:10.6

echo "Warte auf MariaDB..."
sleep 30

echo "Importiere Dump..."
docker exec -i mariadb_migration mysql -uroot -p1 fade_db < ./dump.sql

upgrade() {
  local VERSION=$1 PHP=$2 URL=$3
  echo "Upgrade auf Moodle $VERSION..."
  curl -sL $URL | tar -xz -C /tmp/
  cp ./config.php /tmp/moodle/config.php
  chmod -R 777 /tmp/moodle
  docker run --rm --network fadenet_migration \
    -v /tmp/moodle:/var/www/html/moodle \
    -v $MOODLEDATA:/var/moodledata \
    -e MOODLE_DB_HOST=mariadb_migration \
    -e MOODLE_DB_NAME=fade_db \
    -e MOODLE_DB_USER=fade_user \
    -e MOODLE_DB_PASSWORD=fade_pw \
    moodlehq/moodle-php-apache:$PHP \
    su -s /bin/bash www-data -c "php /var/www/html/moodle/admin/cli/upgrade.php --non-interactive"
  rm -rf /tmp/moodle
}

upgrade "4.1" "8.0" "https://download.moodle.org/download.php/direct/stable401/moodle-latest-401.tgz"
upgrade "4.4" "8.1" "https://download.moodle.org/download.php/direct/stable404/moodle-latest-404.tgz"

docker exec mariadb_migration mysqldump -uroot -p1 fade_db > ./dump_migriert.sql

docker stop mariadb_migration && docker rm mariadb_migration
docker network rm fadenet_migration 2>/dev/null || true
rm -rf $MOODLEDATA
rm -rf /tmp/moodle 2>/dev/null || true

echo "Fertig"

#sudo systemctl stop apache2
#hier noch port von apache ändern
#und noch den banner irgendwie erscheinen lassen
#sudo sed -i "s|require_once(__DIR__ . '/lib/setup.php');|\$CFG->additionalhtmltopofbody = '<div id="warn-banner" style="background:rgba(255,100,100,0.4)!important;color:#8b0000!important;text-align:center!important;padding:10px 20px!important;position:relative!important;z-index:9999!important;font-family:sans-serif!important;font-size:14px!important;font-weight:bold!important;border:2px solid #8b0000!important;border-radius:8px!important;margin:70px 70px -50px 70px!important">⚠ Diese Moodle-Version ist veraltet und wird nicht mehr unterstuetzt<span onclick="document.getElementById('warn-banner').style.display='none'" style="position:absolute!important;right:15px!important;top:50%!important;transform:translateY(-50%)!important;cursor:pointer!important;font-size:16px!important">✕</span></div>';\nrequire_once(__DIR__ . '/lib/setup.php');|" /var/www/html/config.php

#sudo chown -R 33:33 ~/Docker/volumes/moodle
#docker compose up -d mariadb_158
#docker exec -i mariadb_158 mariadb -uroot -p1 fade_db < ~/dump_migriert.sql
#docker compose up -d moodle_158
#http://localhost/admin und durchklicken
