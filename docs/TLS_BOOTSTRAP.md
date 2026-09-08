# TLS Bootstrap

## Objective

The TLS bootstrap exists because first issuance has a circular dependency:

```text
Nginx HTTPS config needs certificates.
Certificates need HTTP-01 challenge traffic to reach the server.
```

The solution is a temporary HTTP-only stack.

## Phase 1: Prepare DNS

Every hostname in `certbot-domains.txt` must point to the server public IP.

Check:

```bash
while read -r host; do
  [ -z "$host" ] && continue
  dig +short "$host"
done < certbot-domains.txt
```

If a hostname is not ready, remove or comment it from `certbot-domains.txt` before issuing.

## Phase 2: Deploy Bootstrap Nginx

```bash
./deploy.sh bootstrap
```

The bootstrap stack:

- binds port 80.
- serves `/.well-known/acme-challenge/` from the webroot volume.
- does not require certificate files.
- should exist only during first issuance or recovery.

## Phase 3: Issue Certificates

```bash
./deploy.sh certs
```

This calls `scripts/issue-certs.sh`, which uses Certbot with the shared webroot volume.

Expected result:

- certificate files under `nginx-letsencrypt`.
- live certificate path for `swarm-edge`.
- no failed authorization for included domains.

## Phase 4: Remove Bootstrap

```bash
./deploy.sh rm-bootstrap
```

Only one stack should own port 80.

## Phase 5: Deploy Full HTTPS Edge

```bash
./deploy.sh deploy
```

The full edge:

- binds 80 and 443.
- redirects HTTP to HTTPS except ACME paths.
- uses the issued certificate.
- starts the Certbot renewal sidecar.

## Renewal Model

Certbot runs:

```text
certbot renew --webroot -w /var/www/certbot
```

every 12 hours. Nginx reloads every 6 hours from its service command, so renewed certificates are picked up without rebuilding the stack.

## Common Failure Modes

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| ACME authorization fails | DNS not pointing to server | fix DNS or remove hostname temporarily |
| connection refused on port 80 | no bootstrap or edge stack running | deploy bootstrap |
| certificate path missing | full edge deployed before issuance | issue certificates first |
| rate limit from Let's Encrypt | repeated failed production attempts | wait or reduce domain set |
| challenge returns redirect unexpectedly | wrong HTTP config active | inspect `conf.d/00-http.conf` and bootstrap config |

