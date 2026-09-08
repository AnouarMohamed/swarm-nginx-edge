#!/usr/bin/env bash
# Validate shell, route inventory, Swarm rendering, and both Nginx phases before
# a deployment can touch the edge service.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

NGINX_IMAGE="${NGINX_IMAGE:-nginx:1.30.3-alpine@sha256:0d3b80406a13a767339fbe2f41406d6c7da727ab89cf8fae399e81f780f814d1}"

bash -n deploy.sh scripts/*.sh

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

domains_from_file="${tmp_dir}/domains-file"
domains_from_routes="${tmp_dir}/domains-routes"

sed -E 's/[[:space:]]*#.*$//; /^[[:space:]]*$/d; s/^[[:space:]]+//; s/[[:space:]]+$//' \
  certbot-domains.txt | sort -u > "${domains_from_file}"

awk '
  /^[[:space:]]*server_name[[:space:]]+/ {
    for (i = 2; i <= NF; i++) {
      gsub(/;/, "", $i)
      if ($i != "_") print $i
    }
  }
' conf.d/10-routes.conf | sort -u > "${domains_from_routes}"

if ! cmp -s "${domains_from_file}" "${domains_from_routes}"; then
  echo "Error: certbot-domains.txt and conf.d/10-routes.conf do not contain the same hostnames." >&2
  diff -u "${domains_from_file}" "${domains_from_routes}" || true
  exit 1
fi

if grep -REn 'image:[[:space:]]+[^[:space:]]+:(latest|stable)([[:space:]]|$)' \
  nginx.stack.yml nginx.bootstrap.stack.yml; then
  echo "Error: floating image tag found in a Swarm stack." >&2
  exit 1
fi

export EDGE_NETWORK="${EDGE_NETWORK:-edge-net}"
export CONFIG_PREFIX="validation"
export NGINX_CONFIG_VERSION="validation"
export INFRA_HTPASSWD_FILE="./auth/infra.htpasswd.example"
docker stack config -c nginx.bootstrap.stack.yml >/dev/null
docker stack config -c nginx.stack.yml >/dev/null

mkdir -p \
  "${tmp_dir}/full/conf.d" \
  "${tmp_dir}/full/snippets" \
  "${tmp_dir}/full/auth" \
  "${tmp_dir}/full/letsencrypt/live/swarm-edge" \
  "${tmp_dir}/bootstrap/conf.d"

cp nginx.conf "${tmp_dir}/full/nginx.conf"
cp conf.d/default.disabled.conf conf.d/00-http.conf conf.d/10-routes.conf "${tmp_dir}/full/conf.d/"
cp snippets/*.conf "${tmp_dir}/full/snippets/"
cp auth/infra.htpasswd.example "${tmp_dir}/full/auth/infra.htpasswd"
cp nginx.conf "${tmp_dir}/bootstrap/nginx.conf"
cp conf.d/bootstrap.conf "${tmp_dir}/bootstrap/conf.d/default.conf"

openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
  -subj '/CN=validation.invalid' \
  -keyout "${tmp_dir}/full/letsencrypt/live/swarm-edge/privkey.pem" \
  -out "${tmp_dir}/full/letsencrypt/live/swarm-edge/fullchain.pem" \
  >/dev/null 2>&1
cp \
  "${tmp_dir}/full/letsencrypt/live/swarm-edge/fullchain.pem" \
  "${tmp_dir}/full/letsencrypt/live/swarm-edge/chain.pem"

docker run --rm --entrypoint nginx \
  -v "${tmp_dir}/bootstrap/nginx.conf:/etc/nginx/nginx.conf:ro" \
  -v "${tmp_dir}/bootstrap/conf.d:/etc/nginx/conf.d:ro" \
  "${NGINX_IMAGE}" -t

docker run --rm --entrypoint nginx \
  -v "${tmp_dir}/full/nginx.conf:/etc/nginx/nginx.conf:ro" \
  -v "${tmp_dir}/full/conf.d:/etc/nginx/conf.d:ro" \
  -v "${tmp_dir}/full/snippets:/etc/nginx/snippets:ro" \
  -v "${tmp_dir}/full/auth:/etc/nginx/auth:ro" \
  -v "${tmp_dir}/full/letsencrypt:/etc/letsencrypt:ro" \
  "${NGINX_IMAGE}" -t

echo "Nginx edge validation passed: scripts, routes, stacks, bootstrap config, and TLS config."
