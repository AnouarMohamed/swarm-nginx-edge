# Migration From Traefik

## Position

The move from Traefik to Nginx is not a statement that Traefik is bad. It is an operational choice: this infrastructure is small enough that explicit routing is easier to review, explain, and debug than dynamic label discovery.

## What Changed

| Area | Traefik model | Nginx model |
| --- | --- | --- |
| Route source | Docker service labels | `conf.d/10-routes.conf` |
| Discovery | automatic through Docker provider | manual and explicit |
| TLS | ACME built into Traefik | Certbot sidecar and webroot |
| Middleware | labels | snippets |
| Reload | dynamic provider updates | stack redeploy or Nginx reload |
| Debugging | inspect labels and Traefik dashboard | read route file and Nginx logs |
| Exposure risk | label mistakes can expose services | central route review |

## Why This Is Better For The Current Stage

The startup benefits from:

- a single central route catalog.
- no hidden routing behavior in app stack labels.
- easier presentation and onboarding.
- simpler audit of admin/public surfaces.
- deterministic Nginx behavior.
- direct migration path to Kubernetes Ingress later.

## Migration Method

1. Keep application stacks attached to `edge-net`.
2. Build Nginx routes against existing Swarm service DNS names.
3. Stop Traefik so ports 80 and 443 are free.
4. Bootstrap Nginx over HTTP.
5. Issue the SAN certificate.
6. Deploy full HTTPS Nginx.
7. Validate all routes.

## Rollback Method

If Nginx fails during migration:

1. remove or stop the Nginx stack.
2. redeploy Traefik.
3. verify dashboard and routes.
4. inspect Nginx logs/config offline.

The application stacks do not need to move during rollback because the network name is preserved.

## Future K3s Bridge

Nginx route concepts map cleanly to Kubernetes:

| Nginx edge | K3s/Kubernetes |
| --- | --- |
| `server_name` | Ingress host |
| `proxy_pass` | Service backend |
| Certbot webroot | cert-manager HTTP-01 |
| snippets | Ingress annotations / controller config |
| Swarm service DNS | Kubernetes Service DNS |
| Docker config versioning | GitOps desired state |

This makes the Nginx repo a good intermediate architecture before the K3s lab.

