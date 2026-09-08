#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

if [[ -f ".env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source ".env"
    set +a
fi

MODE="${1:-deploy}"
STACK_NAME="${STACK_NAME:-nginx-edge}"
BOOTSTRAP_STACK_NAME="${BOOTSTRAP_STACK_NAME:-nginx-edge-bootstrap}"
EDGE_NETWORK="${EDGE_NETWORK:-edge-net}"
ORIGINAL_CONTEXT="$(docker context show 2>/dev/null || echo default)"

restore_context() {
    docker context use "${ORIGINAL_CONTEXT}" >/dev/null 2>&1 || true
}

handle_error() {
    echo "An error occurred in the script" >&2
    restore_context
}

trap handle_error ERR
trap restore_context EXIT

select_docker_context() {
    local target_context="${DOCKER_CONTEXT:-}"

    # CI and automation should always set DOCKER_CONTEXT explicitly. For an
    # interactive shell we retain the familiar default/remote selection.
    if [[ -n "${target_context}" ]]; then
        docker context inspect "${target_context}" >/dev/null
        docker context use "${target_context}"
        return
    fi

    if [[ ! -t 0 ]]; then
        echo "DOCKER_CONTEXT is unset; using current context ${ORIGINAL_CONTEXT}."
        return
    fi

    echo "Select Docker context:"
    echo "1. Current (${ORIGINAL_CONTEXT})"
    echo "2. Default"
    echo "3. Remote"
    read -r -p "Enter your choice (1, 2 or 3): " choice

    case "${choice}" in
        1) return ;;
        2) docker context use default ;;
        3) docker context use remote ;;
        *)
            echo "Invalid Docker context choice." >&2
            exit 1
            ;;
    esac
}

validate_runtime_auth() {
    local auth_file="auth/infra.htpasswd"

    if [[ ! -s "${auth_file}" ]]; then
        echo "Missing ${auth_file}. Copy the example, generate a real bcrypt hash, and redeploy." >&2
        exit 1
    fi

    if grep -Eq 'replace-this|example|password' "${auth_file}"; then
        echo "${auth_file} still contains a placeholder credential." >&2
        exit 1
    fi
}

ensure_docker_objects() {
    if ! docker network inspect "${EDGE_NETWORK}" >/dev/null 2>&1; then
        docker network create --driver overlay --attachable "${EDGE_NETWORK}"
    fi

    docker volume inspect nginx-letsencrypt >/dev/null 2>&1 || docker volume create nginx-letsencrypt >/dev/null
    docker volume inspect nginx-certbot-webroot >/dev/null 2>&1 || docker volume create nginx-certbot-webroot >/dev/null
    docker volume inspect nginx-logs >/dev/null 2>&1 || docker volume create nginx-logs >/dev/null
}

config_version() {
    sha256sum "$@" | sha256sum | awk '{print substr($1, 1, 12)}'
}

set_full_config_version() {
    CONFIG_PREFIX="${STACK_NAME}"
    NGINX_CONFIG_VERSION="$(config_version \
        nginx.conf \
        conf.d/default.disabled.conf \
        conf.d/00-http.conf \
        conf.d/10-routes.conf \
        snippets/auth-infra.conf \
        snippets/proxy-common.conf \
        snippets/ratelimit-infra.conf \
        snippets/security-headers.conf \
        snippets/security-headers-embed.conf \
        snippets/ssl-params.conf \
        snippets/superset-cors.conf \
        auth/infra.htpasswd)"
    export CONFIG_PREFIX NGINX_CONFIG_VERSION
}

set_bootstrap_config_version() {
    CONFIG_PREFIX="${BOOTSTRAP_STACK_NAME}"
    NGINX_CONFIG_VERSION="$(config_version nginx.conf conf.d/bootstrap.conf)"
    export CONFIG_PREFIX NGINX_CONFIG_VERSION
}

export EDGE_NETWORK

if [[ "${MODE}" != "validate" ]]; then
    select_docker_context
fi

case "${MODE}" in
    bootstrap)
        "${SCRIPT_DIR}/scripts/validate-config.sh"
        ensure_docker_objects
        set_bootstrap_config_version
        docker stack deploy --prune -c nginx.bootstrap.stack.yml "${BOOTSTRAP_STACK_NAME}"
        ;;
    certs)
        ensure_docker_objects
        "${SCRIPT_DIR}/scripts/issue-certs.sh"
        ;;
    deploy | full)
        validate_runtime_auth
        "${SCRIPT_DIR}/scripts/validate-config.sh"
        ensure_docker_objects
        set_full_config_version
        docker stack deploy --prune -c nginx.stack.yml "${STACK_NAME}"
        ;;
    renew)
        ensure_docker_objects
        "${SCRIPT_DIR}/scripts/renew-now.sh"
        ;;
    validate)
        "${SCRIPT_DIR}/scripts/validate-config.sh"
        ;;
    rm-bootstrap)
        docker stack rm "${BOOTSTRAP_STACK_NAME}"
        ;;
    rm)
        docker stack rm "${STACK_NAME}"
        ;;
    *)
        echo "Usage: ./deploy.sh [validate|bootstrap|certs|deploy|renew|rm-bootstrap|rm]" >&2
        exit 1
        ;;
esac
