# Validation Guide

## Local Validation

Shell syntax:

```bash
bash -n deploy.sh scripts/*.sh
```

Run the complete pre-deployment validation:

```bash
./deploy.sh validate
```

This command checks shell syntax, exact route-to-certificate domain parity,
floating image tags, both rendered Swarm files, and containerized `nginx -t`
for the HTTP bootstrap and TLS configurations. It generates a one-day local
self-signed certificate only inside a temporary directory for the TLS syntax test.

After deployment, verify the live task as a separate runtime check:

```bash
docker exec "$(docker ps --filter name=nginx_nginx -q | head -n 1)" nginx -t
docker service ps nginx_nginx
```

Secret scan:

```bash
rg -n "BEGIN|PRIVATE KEY|password=|PASSWORD=|token=|TOKEN=|acme|htpasswd" .
```

Only examples and placeholders should appear.

## Runtime Validation

```bash
docker service ls
docker service ps nginx_nginx
docker service logs nginx_nginx --tail 100
docker service logs nginx_certbot --tail 100
```

## Route Validation

For each route:

```bash
curl -I http://<host>/
curl -Ik https://<host>/
```

Expected:

- HTTP redirects to HTTPS except ACME paths.
- HTTPS certificate is valid.
- upstream returns a known application response.
- admin routes challenge for basic auth.

## Certificate Validation

```bash
docker service logs nginx_certbot --tail 200
```

Check certificate dates externally:

```bash
openssl s_client -connect <host>:443 -servername <host> </dev/null 2>/dev/null \
  | openssl x509 -noout -dates -issuer -subject
```
