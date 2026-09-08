#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CERT_NAME="${CERT_NAME:-swarm-edge}"
DOMAINS_FILE="${DOMAINS_FILE:-${ROOT_DIR}/certbot-domains.txt}"
EMAIL="${LETSENCRYPT_EMAIL:-admin@example.com}"
LETSENCRYPT_VOLUME="${LETSENCRYPT_VOLUME:-nginx-letsencrypt}"
WEBROOT_VOLUME="${WEBROOT_VOLUME:-nginx-certbot-webroot}"
STAGING="${LETSENCRYPT_STAGING:-0}"
CERTBOT_IMAGE="${CERTBOT_IMAGE:-certbot/certbot:v5.8.0@sha256:f70ad0adbb7e117f0fe42a63c553f28ea451edabc0148757b6efcd9735acaa20}"

if [[ ! -f "${DOMAINS_FILE}" ]]; then
    echo "Domain file not found: ${DOMAINS_FILE}" >&2
    exit 1
fi

if [[ "${EMAIL}" == "admin@example.com" || ! "${EMAIL}" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; then
    echo "LETSENCRYPT_EMAIL must be a real, valid operator email address." >&2
    exit 1
fi

if [[ ! "${CERT_NAME}" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "CERT_NAME contains unsupported characters." >&2
    exit 1
fi

if [[ "${STAGING}" != "0" && "${STAGING}" != "1" ]]; then
    echo "LETSENCRYPT_STAGING must be 0 or 1." >&2
    exit 1
fi

domains=()
declare -A seen_domains=()
while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%%#*}"
    line="$(echo "${line}" | xargs)"
    [[ -z "${line}" ]] && continue
    if [[ ! "${line}" =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}$ ]]; then
        echo "Invalid DNS hostname in ${DOMAINS_FILE}: ${line}" >&2
        exit 1
    fi
    if [[ -n "${seen_domains[${line}]:-}" ]]; then
        echo "Duplicate hostname in ${DOMAINS_FILE}: ${line}" >&2
        exit 1
    fi
    seen_domains["${line}"]=1
    domains+=("${line}")
done < "${DOMAINS_FILE}"

if [[ "${#domains[@]}" -eq 0 ]]; then
    echo "No domains found in ${DOMAINS_FILE}" >&2
    exit 1
fi

args=(
    run
    --rm
    -v "${LETSENCRYPT_VOLUME}:/etc/letsencrypt"
    -v "${WEBROOT_VOLUME}:/var/www/certbot"
    "${CERTBOT_IMAGE}"
    certonly
    --webroot
    -w /var/www/certbot
    --cert-name "${CERT_NAME}"
    --email "${EMAIL}"
    --agree-tos
    --non-interactive
    --no-eff-email
    --keep-until-expiring
    --expand
)

if [[ "${STAGING}" == "1" ]]; then
    args+=(--staging)
fi

for domain in "${domains[@]}"; do
    args+=(-d "${domain}")
done

docker "${args[@]}"
