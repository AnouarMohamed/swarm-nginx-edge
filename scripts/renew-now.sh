#!/usr/bin/env bash

set -Eeuo pipefail

STACK_NAME="${STACK_NAME:-nginx-edge}"
LETSENCRYPT_VOLUME="${LETSENCRYPT_VOLUME:-nginx-letsencrypt}"
WEBROOT_VOLUME="${WEBROOT_VOLUME:-nginx-certbot-webroot}"
CERTBOT_IMAGE="${CERTBOT_IMAGE:-certbot/certbot:v5.8.0@sha256:f70ad0adbb7e117f0fe42a63c553f28ea451edabc0148757b6efcd9735acaa20}"

docker run --rm \
    -v "${LETSENCRYPT_VOLUME}:/etc/letsencrypt" \
    -v "${WEBROOT_VOLUME}:/var/www/certbot" \
    "${CERTBOT_IMAGE}" \
    renew \
    --webroot \
    -w /var/www/certbot \
    --no-random-sleep-on-renew

if docker service inspect "${STACK_NAME}_nginx" >/dev/null 2>&1; then
    docker service update --force "${STACK_NAME}_nginx"
fi
