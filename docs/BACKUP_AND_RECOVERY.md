# Backup And Recovery

## Scope

The Nginx edge owns proxy configuration and certificate material. It does not own application data. Application backups belong to the app/database repos and stacks.

## What Must Be Recoverable

| Asset | Location | Recovery importance |
| --- | --- | --- |
| Git repository | GitHub/local clone | rebuild edge config |
| `.env` | local only | stack names, edge network, email |
| `auth/infra.htpasswd` | local ignored file | infrastructure route protection |
| certificate material | `nginx-letsencrypt` volume | avoid forced reissuance and rate limits |
| webroot | `nginx-certbot-webroot` volume | ACME challenge continuity |
| logs | `nginx-logs` volume | incident investigation |

## Minimal Backup Procedure

Archive local operational files:

```bash
tar czf nginx-edge-runtime-backup.tgz .env auth/infra.htpasswd
```

Back up Docker volumes from the manager:

```bash
docker run --rm \
  -v nginx-letsencrypt:/data:ro \
  -v "$PWD:/backup" \
  alpine tar czf /backup/nginx-letsencrypt-backup.tgz -C /data .
```

Repeat for logs if needed:

```bash
docker run --rm \
  -v nginx-logs:/data:ro \
  -v "$PWD:/backup" \
  alpine tar czf /backup/nginx-logs-backup.tgz -C /data .
```

## Recovery Procedure

1. clone the repo.
2. restore `.env`.
3. restore `auth/infra.htpasswd`.
4. recreate external volumes.
5. restore certificate volume if available.
6. create or verify edge network.
7. deploy the full edge.

Commands:

```bash
docker network create --driver overlay --attachable edge-net || true
docker volume create nginx-letsencrypt || true
docker volume create nginx-certbot-webroot || true
docker volume create nginx-logs || true
./deploy.sh deploy
```

If certificate material is unavailable:

```bash
./deploy.sh bootstrap
./deploy.sh certs
./deploy.sh rm-bootstrap
./deploy.sh deploy
```

## Recovery Priorities

1. restore port 80/443 edge service.
2. restore valid certificates.
3. restore infrastructure auth.
4. validate public routes.
5. inspect app-specific failures.

## Restore Test

A backup is not valid until restored on a test node or lab environment. At minimum, verify that:

- certificate files are readable.
- Nginx can start.
- `nginx -t` passes.
- a protected route still challenges for auth.
- Certbot can run a dry renewal or normal renewal check.

