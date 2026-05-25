#!/bin/bash
set -e

#Folgende Dateien müssen so im verzeichnis sein, ich empfehle alle dateien im Home verzeichnis zu haben und dieses script da auszuführen:
#.
#|-- migrate.sh
#|-- config.php
#|-- mariadb_pw.txt
#|-- config_migration.php
#|-- docker-compose.yml
#└-- Dockerfile

echo "Passwortfile check..."
if [ ! -f "./mariadb_pw.txt" ]; then
    echo "Fehler: Passwort-File './mariadb_pw.txt' fehlt."
    read -p "MariaDB Passwort für DB-User eingeben: " password
    touch mariadb_pw.txt
    echo "$password" > "./mariadb_pw.txt"
    echo "Passwort wurde in './mariadb_pw.txt' gespeichert."
fi

#evtl noch den dump selbst erstellen?
echo "Erstelle Dump..."
sudo mysqldump -u root moodle > dump.sql

MOODLEDATA=/tmp/moodledata
mkdir -p $MOODLEDATA
chmod 777 $MOODLEDATA

echo "Erstelle Docker Netzwerk..."
docker network create fadenet_migration 2>/dev/null || true

echo "Starte MariaDB_migration Container..."
docker rm -f mariadb_migration 2>/dev/null || true
docker run -d --name mariadb_migration --network fadenet_migration \
  -e MARIADB_ROOT_PASSWORD=1 \
  -e MARIADB_DATABASE=fade_db \
  -e MARIADB_USER=fade_user \
  -e MARIADB_PASSWORD=fade_pw \
  mariadb:10.6

echo "Warte auf MariaDB..."
until docker exec mariadb_migration mysql -uroot -p1 -e "SELECT 1" &>/dev/null; do
  sleep 1
done

echo "Importiere Dump..."
docker exec -i mariadb_migration mysql -uroot -p1 fade_db < ./dump.sql

upgrade() {
  local VERSION=$1 PHP=$2 URL=$3
  echo "Upgrade auf Moodle $VERSION..."
  curl -sL $URL | tar -xz -C /tmp/
  cp ./config_migration.php /tmp/moodle/config.php
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

echo "Exportiere migrierten Dump..."
docker exec mariadb_migration mysqldump -uroot -p1 fade_db > ./dump_migriert.sql

echo "Bereinige Migration..."
docker stop mariadb_migration && docker rm mariadb_migration
docker network rm fadenet_migration 2>/dev/null || true
rm -rf $MOODLEDATA
rm -rf /tmp/moodle 2>/dev/null || true

echo "Migration Fertig"

# Apache stoppen
echo "Stoppe Apache..."
sudo systemctl stop apache2

#hier noch port von apache ändern
#Bare metal install auf port 8080 wechseln
echo "Ändere Apache Port auf 8080..."
sudo sed -i "s/Listen 80/Listen 8080/" /etc/apache2/ports.conf
#änderung da links in moodle noch auf localhost statt localhost:8080 zeigen (die vielen sternchen, da jemand nicht schön konfiguriert und mehrere leerzeichen. keinen bock das statisch zu machen)
sudo sed -i "s|.*wwwroot.*=.*'http://localhost'.*|\$CFG->wwwroot = 'http://localhost:8080';|" /var/www/html/config.php

#und noch den banner irgendwie erscheinen lassen
echo "Füge Warnbanner hinzu..."
cat > /tmp/banner.php << 'EOF'
$CFG->additionalhtmltopofbody = "<div id=\"warn-banner\" style=\"background:rgba(255,100,100,0.4)!important;color:#8b0000!important;text-align:center!important;padding:10px 20px!important;position:relative!important;z-index:9999!important;font-family:sans-serif!important;font-size:14px!important;font-weight:bold!important;border:2px solid #8b0000!important;border-radius:8px!important;margin:70px 70px -50px 70px!important\">⚠ Diese Moodle-Version ist veraltet und wird nicht mehr unterstützt<span onclick=\"document.getElementById('warn-banner').style.display='none'\" style=\"position:absolute!important;right:15px!important;top:50%!important;transform:translateY(-50%)!important;cursor:pointer!important;font-size:16px!important\">✕</span></div>";
EOF
sudo sed -i "/require_once/e cat /tmp/banner.php" /var/www/html/config.php


#oprdner erstellen
echo "Erstelle Ordner für Docker..."
mkdir -p ~/Docker/moodle_158/data
mkdir -p ~/Docker/moodle_158/secrets

#docker compose dateien hineinkopieren
echo "Kopiere Docker Dateien..."
mv ./Dockerfile ./docker-compose.yml ./config.php ~/Docker/moodle_158/
mv ./mariadb_pw.txt ~/Docker/moodle_158/secrets/

#Docker Image bauen
echo "Baue Docker Image..."
docker build -t moodlefade:latest ~/Docker/moodle_158/

#Directory wechseln
cd ~/Docker/moodle_158/

#DB starten
echo "Starte MariaDB Container..."
docker compose up -d mariadb_158

#Auf DB warten
echo "Warte auf MariaDB..."
sleep 30

#lowkenuenly kein bock zum fixxen desswegen einfach wieder sleep 30
#until docker exec mariadb_158 mysql -ufade_user -p"$(cat ~/Docker/moodle_158/secrets/mariadb_pw.txt)" -e "SELECT 1" &>/dev/null; do
#  sleep 1
#done

#Dump Importieren
echo "Importiere migrierten Dump in MariaDB Container..."
docker exec -i mariadb_158 mariadb -ufade_user -p"$(cat ~/Docker/moodle_158/secrets/mariadb_pw.txt)" fade_db < ~/dump_migriert.sql

#Moodle starten
echo "Starte Moodle Container..."
docker compose up -d moodle_158

#Dateirechte setzen
echo "Setze Dateirechte..."
sudo chown -R 33:33 ~/Docker/moodle_158/data/moodle
sudo chmod -R 755 ~/Docker/moodle_158/data/moodle

#Apache starten
echo "Starte altes Moodle..."
sudo systemctl start apache2

#Alles Fertig
echo "Moodle ist jetzt unter http://localhost:80 erreichbar (Apache auf 8080, Docker auf 80)!"
#http://localhost/admin und durchklicken
nohup firefox --new-window http://localhost:8080 --new-tab http://localhost/admin &

#SQL cleanup
echo "SQL Cleanup..."
rm ~/dump.sql
rm ~/dump_migriert.sql
