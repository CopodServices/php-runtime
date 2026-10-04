#!/bin/sh
# Prepares writable state on the data volume, renders the nginx config, then
# supervises PHP-FPM and nginx in the foreground.
set -eu

RUNTIME=/mnt/server/.runtime
DATA=/mnt/server

mkdir -p \
    "$RUNTIME/nginx/client_body" "$RUNTIME/nginx/proxy" "$RUNTIME/nginx/fastcgi" \
    "$RUNTIME/nginx/uwsgi" "$RUNTIME/nginx/scgi" \
    "$RUNTIME/php/sessions" "$RUNTIME/php/uploads" "$RUNTIME/php/conf.d" \
    "$RUNTIME/tmp"

# Document root: a public/ directory wins, otherwise the volume root itself.
if [ -d "$DATA/public" ]; then
    ln -sfn "$DATA/public" "$RUNTIME/www"
else
    ln -sfn "$DATA" "$RUNTIME/www"
fi

cat > "$RUNTIME/php/conf.d/zz-panel-env.ini" <<EOF
memory_limit = ${PHP_MEMORY_LIMIT:-256M}
upload_max_filesize = ${PHP_UPLOAD_MAX_SIZE:-64M}
post_max_size = ${PHP_UPLOAD_MAX_SIZE:-64M}
EOF

export PHP_INI_SCAN_DIR="/usr/local/etc/php/conf.d:$RUNTIME/php/conf.d"
export SERVER_PORT="${SERVER_PORT:-8080}"

sed "s/__PORT__/${SERVER_PORT}/g" /etc/nginx/panel.conf.template > "$RUNTIME/nginx/nginx.conf"

echo "panel-php: serving $DATA (docroot $(readlink "$RUNTIME/www")) on :$SERVER_PORT"

php-fpm --nodaemonize --fpm-config /usr/local/etc/php-fpm.conf &
FPM_PID=$!

nginx -c "$RUNTIME/nginx/nginx.conf" -g "daemon off;" &
NGINX_PID=$!

term() {
    kill -TERM "$NGINX_PID" "$FPM_PID" 2>/dev/null || true
    wait "$NGINX_PID" 2>/dev/null || true
    wait "$FPM_PID" 2>/dev/null || true
    exit 0
}
trap term TERM INT

# Exit when either process dies so the daemon restarts the workload.
while kill -0 "$NGINX_PID" 2>/dev/null && kill -0 "$FPM_PID" 2>/dev/null; do
    sleep 2
done
term
