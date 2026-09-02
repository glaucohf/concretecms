#!/bin/bash

PORT="${PORT:-8080}"
sed -i "s/Listen 80/Listen ${PORT}/" /etc/apache2/ports.conf
sed -i "s/:80>/:${PORT}>/" /etc/apache2/sites-enabled/000-default.conf

# php:8.2-apache ships both mpm_prefork (required by mod_php) and mpm_event
# enabled, which makes apache refuse to start. Disabling this at build time
# didn't stick on Railway's builder, so enforce it here at boot instead.
a2dismod -f mpm_event >/dev/null 2>&1
a2enmod mpm_prefork >/dev/null 2>&1

cd /var/www/html

# Single Railway volume is mounted at /data; symlink the two paths
# ConcreteCMS needs writable/persistent so we don't overlay all of application/.
mkdir -p /data/config /data/files
rm -rf application/config application/files
ln -sfn /data/config application/config
ln -sfn /data/files application/files
chown -h www-data:www-data application/config application/files
chown -R www-data:www-data /data/config /data/files

if ! su -s /bin/bash www-data -c "php concrete/bin/concrete5 c5:is-installed --quiet"; then
    echo "Concrete CMS is not installed yet — running installer..."
    su -s /bin/bash www-data -c "php concrete/bin/concrete5 c5:install \
        --ansi --no-interaction \
        --db-server=\"${DB_HOST}\" \
        --db-username=\"${DB_USER}\" \
        --db-password=\"${DB_PASSWORD}\" \
        --db-database=\"${DB_DATABASE}\" \
        --timezone=UTC \
        --site=\"${SITE_NAME:-Concrete CMS}\" \
        --starting-point=\"${STARTING_POINT:-atomik_full}\" \
        --admin-email=\"${ADMIN_EMAIL}\" \
        --admin-password=\"${ADMIN_PASSWORD}\" \
        --canonical-url=\"${CANONICAL_URL}\""
else
    echo "Concrete CMS already installed — skipping installer."
fi

exec "$@"
