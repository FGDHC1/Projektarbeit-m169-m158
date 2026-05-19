# Ubuntu als Base Image
FROM ubuntu:24.04 

# Apache + PHP + benoetigte Pakete installieren
RUN apt-get update && apt-get install -y apache2 \
    php php-mysql php-xml php-mbstring \
    php-curl php-zip php-gd php-intl \
    php-soap php-ldap curl unzip \
    && apt-get clean

# Moodle installieren
RUN LATEST_URL=$(curl -s https://download.moodle.org/releases/latest/ \
        | grep -oP 'https://download\.moodle\.org/download\.php/stable\d+/moodle-latest-\d+\.tgz' \
        | head -1) \
    && curl -L "$LATEST_URL" -o /tmp/moodle.tgz \
    && tar -xvf /tmp/moodle.tgz -C /var/www/html/ \
    && rm /tmp/moodle.tgz

# Datenverzeichnis erstellen
RUN mkdir -p /var/moodledata \
    && chown -R www-data:www-data /var/moodledata \
    && chmod 777 /var/moodledata \
    && chown -R www-data:www-data /var/www/html/moodle

# standart index.html löschen
RUN rm -f /var/www/html/index.html

# max_input_vars erhöhen
RUN PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;') \
    && echo 'max_input_vars = 5000' >> /etc/php/${PHP_VER}/apache2/php.ini

# config.php in den Container kopieren
COPY config.php /var/www/html/moodle/config.php

# Rechte fuer config.php setzen
RUN chown www-data:www-data /var/www/html/moodle/config.php

# Composer installieren
RUN apt-get install -y composer \
    && cd /var/www/html/moodle \
    && composer install --no-dev --classmap-authoritative

# Apache Konfiguration
RUN echo '<VirtualHost *:80>\n\
    DocumentRoot /var/www/html/moodle/public\n\
    <Directory /var/www/html/moodle/public>\n\
        AllowOverride All\n\
        Require all granted\n\
    </Directory>\n\
</VirtualHost>' > /etc/apache2/sites-available/000-default.conf \
    && a2enmod rewrite

EXPOSE 80

CMD ["apachectl", "-D", "FOREGROUND"]