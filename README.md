# Swarm Nginx Edge

This repository documents the Nginx replacement for the original Traefik edge stack. It is a presentation-ready and sanitized reference for a Docker Swarm reverse proxy migration.

Presentation and learning notes: [DevOps infrastructure defense guide](https://github.com/AnouarMohamed/devops-infrastructure-defense-guide).

It keeps the same public routes, TLS through Let's Encrypt, HTTP to HTTPS redirects, infrastructure basic auth, rate limiting, compression, security headers, and Docker Swarm deployment style.

## Design

- `nginx.stack.yml` runs Nginx on ports `80` and `443` and a Certbot renewer sidecar.
- `nginx.bootstrap.stack.yml` is an HTTP-only bootstrap used before the first certificate exists.
- `certbot-domains.txt` is the single source of truth for the SAN certificate named `swarm-edge`.
- The default edge network is `edge-net` so the existing app stacks work without editing every service. To move to a cleaner network later, deploy with `EDGE_NETWORK=nginx-net` and attach every routed service to that network.
- Nginx targets Swarm service DNS names such as `wordpress-portfolio_wp:80`, not local Compose service keys like `wp`.
- `deploy.sh` versions Swarm config objects from a content hash, so route and snippet edits roll forward on redeploy.
- Nginx and Certbot use explicit version plus manifest-list digest pins; upgrades are reviewed changes, not tag drift.
- Unknown HTTP and HTTPS hosts are closed with `444`; only the declared certificate hostnames may redirect to HTTPS.

## Routes

| Host | Upstream | Protection |
| --- | --- | --- |
| `db-admin.example.com` | `mysql-admin_phpmyadmin:80` | basic auth |
| `db-development.example.com` | `mysql-development_phpmyadmin:80` | basic auth |
| `mongodb-admin.example.com` | `mongodb_mongo-express:8081` | rate limit |
| `portainer.example.com` | `portainer_portainer:9000` | rate limit |
| `jenkins.example.com` | `jenkins_jenkins:8080` | basic auth |
| `glpi.example.com` | `glpi_glpi:80` | rate limit |
| `superset.example.com` | `superset_superset:8088` | Superset CORS headers, embed-safe security headers |
| `passbolt.example.com` | `passbolt_passbolt:8080` | rate limit |
| `wordpress-school.example.com` | `wordpress-school_wp:80` | basic auth |
| `wordpress-invoice.example.com` | `wordpress-invoice_wp:80` | basic auth |
| `wordpress-portfolio.example.com` | `wordpress-portfolio_wp:80` | public |
| `wordpress-community.example.com` | `wordpress-community_wp:80` | public |
| `wordpress-resume.example.com` | `wordpress-resume_wp:80` | public |
| `wordpress-blog.example.com` | `wordpress-blog_wp:80` | public |
| `edge-status.example.com` | Nginx status/health | basic auth and rate limit |

## First Deployment

Only run this section when you intentionally want to replace Traefik. Stop Traefik first, because both stacks need ports `80` and `443`.

Run these from the `nginx/` folder:

```bash
./deploy.sh validate
./deploy.sh bootstrap
./deploy.sh certs
./deploy.sh rm-bootstrap
./deploy.sh deploy
```

If any DNS record is not pointed at the server yet, comment that hostname out of `certbot-domains.txt`, run `./deploy.sh certs`, then add it back when DNS is ready.

## Renewals

The `certbot` service runs `certbot renew` every 12 hours. The Nginx service reloads every 6 hours so renewed certificates are picked up without a manual restart.

For an immediate renewal and Nginx restart:

```bash
./deploy.sh renew
```

## Basic Auth

The runtime infra auth file is `auth/infra.htpasswd`. It is intentionally ignored by Git.
Deployment stops with a clear error if the file is missing or still contains the sample placeholder.

Start from the sample:

```bash
cp auth/infra.htpasswd.example auth/infra.htpasswd
```

To replace it:

```bash
docker run --rm httpd:2.4 htpasswd -nbB admin 'new-password'
```

Paste the output into `auth/infra.htpasswd`, then redeploy:

```bash
./deploy.sh deploy
```

## Adding A New Route

1. Attach the target service to the edge network (`edge-net` by default).
2. Add a `server` block in `conf.d/10-routes.conf`.
3. Add the hostname to `certbot-domains.txt`.
4. Run `./deploy.sh validate`; it rejects any route/certificate inventory mismatch.
5. Run `./deploy.sh certs` and `./deploy.sh deploy`.

Use the deployed stack service name for upstreams. For example, stack `my-site` with service `wp` becomes `my-site_wp:80`.

## Security Defaults

- TLS 1.2 and TLS 1.3 only.
- One Let's Encrypt SAN certificate for all current routes.
- HTTP redirects to HTTPS, except ACME challenges.
- HSTS, content type protection, same-origin frame policy, strict referrer policy, and permissions policy.
- Global gzip compression for text assets.
- Per-IP infrastructure rate limit aligned with the hardened Traefik baseline: `30r/s` with `burst=120`.
- Unknown HTTPS hosts are closed with `444`.
- A local `/healthz` probe controls Swarm task health without exposing an administrative endpoint.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Operations](docs/OPERATIONS.md)
- [Security](docs/SECURITY.md)
- [Migration From Traefik](docs/MIGRATION_FROM_TRAEFIK.md)
- [Route Catalog](docs/ROUTE_CATALOG.md)
- [Architecture Decisions](docs/DECISIONS.md)
- [Dependency Map](docs/DEPENDENCIES.md)
- [TLS Bootstrap](docs/TLS_BOOTSTRAP.md)
- [Configuration Reference](docs/CONFIG_REFERENCE.md)
- [Change Management](docs/CHANGE_MANAGEMENT.md)
- [Observability](docs/OBSERVABILITY.md)
- [Backup And Recovery](docs/BACKUP_AND_RECOVERY.md)
- [Production Readiness](docs/PRODUCTION_READINESS.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Validation Guide](docs/VALIDATION.md)
- [Architecture Diagrams](docs/DIAGRAMS.md)
- [Stack Names](docs/STACK_NAMES.md)
- [Runbooks](runbooks/README.md)
