# Troubleshooting

## Triage Order

Use this order:

1. DNS.
2. ports 80/443.
3. Nginx task health.
4. Nginx config syntax.
5. certificate existence/validity.
6. route match.
7. upstream DNS.
8. upstream service health.

## DNS Fails

```bash
dig +short <host>
```

If the result is wrong, fix DNS before debugging Nginx.

## Port 80 Or 443 Fails

```bash
sudo ss -tulpn | rg ':80|:443'
docker service ls
```

Only one stack can bind the public ports.

## Nginx Task Fails

```bash
docker service ps nginx_nginx --no-trunc
docker service logs nginx_nginx --tail 200
```

Common causes:

- missing certificate files.
- missing htpasswd config source.
- invalid Nginx syntax.
- port conflict.

## Config Syntax Fails

```bash
container="$(docker ps --filter name=nginx_nginx -q | head -n 1)"
docker exec "$container" nginx -t
```

Fix the referenced file, commit, and redeploy.

## HTTPS Fails But HTTP Works

Likely causes:

- certificate not issued yet.
- wrong certificate path.
- full edge deployed before bootstrap.
- client is using an unknown hostname and receives `444`.

Check:

```bash
docker service logs nginx_certbot --tail 200
openssl s_client -connect <host>:443 -servername <host> </dev/null
```

## Route Returns 502

Likely causes:

- upstream service name is wrong.
- upstream service is not on `edge-net`.
- target port is wrong.
- app task is unhealthy.

Check:

```bash
docker service ls
docker service ps <stack>_<service>
container="$(docker ps --filter name=nginx_nginx -q | head -n 1)"
docker exec "$container" getent hosts <stack>_<service>
```

## Route Returns 401

This is expected for protected routes. If credentials fail:

- regenerate `auth/infra.htpasswd`.
- redeploy so the Docker config hash changes.
- verify browser is not caching old credentials.

## Superset Embedding Fails

Check:

- `security-headers-embed.conf` is included, not the default frame policy.
- `superset-cors.conf` is included.
- Superset app config allows the intended embedding origin.
- browser console for CORS or frame errors.

