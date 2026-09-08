# Route Catalog

## Public And Infrastructure Routes

| Host | Upstream | Type | Edge controls |
| --- | --- | --- | --- |
| `db-admin.example.com` | `mysql-admin_phpmyadmin:80` | infrastructure | basic auth |
| `db-development.example.com` | `mysql-development_phpmyadmin:80` | infrastructure | basic auth |
| `mongodb-admin.example.com` | `mongodb_mongo-express:8081` | infrastructure | rate limit |
| `portainer.example.com` | `portainer_portainer:9000` | infrastructure | rate limit |
| `jenkins.example.com` | `jenkins_jenkins:8080` | infrastructure | basic auth |
| `glpi.example.com` | `glpi_glpi:80` | business app | rate limit |
| `superset.example.com` | `superset_superset:8088` | BI app | Superset CORS and embed headers |
| `passbolt.example.com` | `passbolt_passbolt:8080` | password manager | rate limit |
| `wordpress-school.example.com` | `wordpress-school_wp:80` | WordPress | basic auth |
| `wordpress-invoice.example.com` | `wordpress-invoice_wp:80` | WordPress | basic auth |
| `wordpress-portfolio.example.com` | `wordpress-portfolio_wp:80` | WordPress | public |
| `wordpress-community.example.com` | `wordpress-community_wp:80` | WordPress | public |
| `wordpress-resume.example.com` | `wordpress-resume_wp:80` | WordPress | public |
| `wordpress-blog.example.com` | `wordpress-blog_wp:80` | WordPress | public |
| `edge-status.example.com` | Nginx status/health | infrastructure | basic auth and rate limit |

## Route Review Checklist

Before adding a route:

- Is the hostname in DNS?
- Is the service attached to the edge network?
- Is the upstream service name correct?
- Is the route public or administrative?
- Does it need basic auth?
- Does it need special headers?
- Does it need larger upload limits?
- Is the hostname in `certbot-domains.txt`?
- Has `./deploy.sh certs` been run?
- Has HTTPS been tested?

