FROM php:8.2-apache

RUN apt-get update && apt-get install -y --no-install-recommends \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libzip-dev \
        libicu-dev \
        libxml2-dev \
        unzip \
        git \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        gd \
        pdo_mysql \
        mysqli \
        zip \
        intl \
        opcache \
        dom \
        simplexml \
    && rm -rf /var/lib/apt/lists/*

# Separate layer (never cache-hit from earlier builds that predate this fix):
# php:8.2-apache ships both mpm_prefork (required by mod_php, non-threaded)
# and mpm_event enabled, which makes apache refuse to start ("More than one
# MPM loaded"). Force only prefork to stay enabled.
RUN a2enmod rewrite \
    && a2dismod -f mpm_event \
    && a2enmod mpm_prefork \
    && apachectl configtest

COPY --from=composer:2.2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

COPY . .

# Pinned to Composer 2.2: newer 2.x releases have a pre-autoload-dump
# incompatibility with wikimedia/composer-merge-plugin 2.0.1 that silently
# skips merging concrete/composer.json's autoload rules (Concrete\Core\ never
# gets mapped to concrete/src, causing a "class not found" fatal at runtime).
RUN composer install --optimize-autoloader --no-dev --no-interaction --no-progress --no-cache

RUN chown -R www-data:www-data /var/www/html

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["entrypoint.sh"]
CMD ["apache2-foreground"]
