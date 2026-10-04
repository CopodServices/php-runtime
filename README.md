# php-runtime

Public nginx + PHP-FPM images for **cPOD Panel**-hosted websites, published to
`ghcr.io/copodservices/php-runtime`.

One image per PHP version (8.1 – 8.4), built for the CopodServices daemon pod
contract:

- runs as uid/gid **988**, non-root, all capabilities dropped (`RuntimeDefault` seccomp)
- listens on **`SERVER_PORT`** (the allocated port the daemon injects), default `8080`
- document root `/mnt/server/public` when it exists, otherwise `/mnt/server`
- **read-only root filesystem** safe: every writable path (nginx temp + pid, PHP
  sessions, uploads, `/tmp`) lives under `/mnt/server/.runtime`
- `WorkingDir`/`HOME` are `/mnt/server`

Extensions: `pdo_pgsql`, `mbstring`, `intl`, `zip`, `curl`, `gd`, `opcache`.
A `pdo_mysql` build arg is reserved for a future MySQL provider.

## Tags

| Tag | Meaning |
| --- | --- |
| `8.3-20261004-abc1234` | Immutable build (date + short SHA) |
| `8.3` | Newest build of that PHP version on `main` |
| `latest` | Newest stable PHP version at release time |

## Usage in the panel

The panel renders the image from `PHP_RUNTIME_IMAGE_TEMPLATE`
(`ghcr.io/copodservices/php-runtime:{version}`) and injects `SERVER_PORT`,
`DOCUMENT_ROOT`, `PHP_MEMORY_LIMIT` and `DB_*` variables. No other flags are
needed — the entrypoint configures nginx and PHP-FPM from the environment.

## Local build

```bash
docker build --build-arg PHP_VERSION=8.3 -t php-runtime:dev .
docker run --rm -p 8080:8080 \
  -v "$PWD/site:/mnt/server" \
  -e SERVER_PORT=8080 \
  php-runtime:dev
```

Always mount something at `/mnt/server`: the image's writable state (`/tmp`,
nginx, PHP sessions) lives there because the daemon runs the container with a
read-only root filesystem.

Place a site at `site/` (`public/index.php` for a public document root, or any
`index.php`/`index.html` at the root).
