# nginx + PHP-FPM for cPOD-hosted sites.
#
# Pod contract (CopodServices daemon): non-root uid/gid 988, read-only root
# filesystem, writable state under /mnt/server/.runtime, listen on $SERVER_PORT.
ARG PHP_VERSION=8.3
FROM php:${PHP_VERSION}-fpm-alpine

ARG PHP_VERSION

RUN apk add --no-cache nginx \
    && apk add --no-cache --virtual .build-deps \
        libpq-dev icu-dev libzip-dev freetype-dev libjpeg-turbo-dev libpng-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" pdo_pgsql intl zip gd opcache \
    && apk del .build-deps

# Writable state has to live on the mounted volume because the root filesystem
# is read-only at runtime. /tmp is a symlink into it; the entrypoint creates the
# target directories before anything writes there.
RUN rm -rf /tmp && ln -s /mnt/server/.runtime/tmp /tmp \
    && mkdir -p /mnt/server/.runtime

COPY docker/nginx.conf.template /etc/nginx/panel.conf.template
COPY docker/php-panel.ini /usr/local/etc/php/conf.d/zz-panel.ini
COPY docker/entrypoint.sh /usr/local/bin/panel-entrypoint
RUN chmod +x /usr/local/bin/panel-entrypoint

USER 988:988

ENV SERVER_PORT=8080 \
    DOCUMENT_ROOT=/mnt/server/public

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/panel-entrypoint"]
