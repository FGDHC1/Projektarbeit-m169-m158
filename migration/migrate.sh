#!/bin/bash

set -e

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
