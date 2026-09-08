# Dependency Map

## Runtime Dependencies

| Dependency | Why it matters | Failure impact |
| --- | --- | --- |
| Docker Swarm manager node | Nginx and Certbot are placed on a manager | edge cannot schedule if manager is unhealthy |
| `edge-net` overlay network | connects Nginx to application services | routes return 502 or cannot resolve upstreams |
| ports 80 and 443 | public HTTP/S entrypoints | edge cannot receive traffic |
| DNS records | hostnames must point to the server | clients and ACME validation fail |
| `nginx-letsencrypt` volume | stores certificates and account material | HTTPS cannot start or renew |
| `nginx-certbot-webroot` volume | serves HTTP-01 challenge files | certificate issuance fails |
| `nginx-logs` volume | stores logs | debugging becomes weak |
| `auth/infra.htpasswd` | protects infrastructure routes | deploy can fail or admin routes become unprotected if misconfigured |

## Upstream Service Dependencies

| Route | Required Swarm service | Required port |
| --- | --- | --- |
| `db-admin.example.com` | `mysql-admin_phpmyadmin` | `80` |
| `db-development.example.com` | `mysql-development_phpmyadmin` | `80` |
| `mongodb-admin.example.com` | `mongodb_mongo-express` | `8081` |
| `portainer.example.com` | `portainer_portainer` | `9000` |
| `jenkins.example.com` | `jenkins_jenkins` | `8080` |
| `glpi.example.com` | `glpi_glpi` | `80` |
| `superset.example.com` | `superset_superset` | `8088` |
| `passbolt.example.com` | `passbolt_passbolt` | `8080` |
| `wordpress-school.example.com` | `wordpress-school_wp` | `80` |
| `wordpress-invoice.example.com` | `wordpress-invoice_wp` | `80` |
| `wordpress-portfolio.example.com` | `wordpress-portfolio_wp` | `80` |
| `wordpress-community.example.com` | `wordpress-community_wp` | `80` |
| `wordpress-resume.example.com` | `wordpress-resume_wp` | `80` |
| `wordpress-blog.example.com` | `wordpress-blog_wp` | `80` |

## Deployment Dependencies

The deployment script assumes:

- Docker is installed.
- the operator can switch Docker context.
- `sha256sum` is available.
- the edge network can be inspected or created.
- required volumes can be inspected or created.
- `auth/infra.htpasswd` exists before full deployment.

## Dependency Validation Commands

```bash
docker node ls
docker network inspect edge-net
docker volume inspect nginx-letsencrypt
docker volume inspect nginx-certbot-webroot
docker volume inspect nginx-logs
docker service ls
```

Validate one upstream from inside the Nginx task:

```bash
docker exec $(docker ps --filter name=nginx_nginx -q | head -n 1) \
  getent hosts mysql-admin_phpmyadmin
```

## Critical Path

```text
DNS -> public ports -> Nginx task -> certificate files -> route block -> Swarm DNS -> upstream service
```

When debugging, follow that order. Jumping directly to application logs can waste time if the failure is DNS, TLS, network, or upstream resolution.

