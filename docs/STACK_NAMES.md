# Stack names

| Stack | Default name | Purpose |
|---|---|---|
| Final edge | `nginx-edge` | Nginx HTTPS edge and Certbot renewer. |
| Bootstrap edge | `nginx-edge-bootstrap` | Temporary HTTP-only service for initial ACME issuance. |

Both names can be overridden for an intentional parallel environment:

```bash
STACK_NAME=nginx-edge-staging \
BOOTSTRAP_STACK_NAME=nginx-edge-staging-bootstrap \
DOCKER_CONTEXT=staging \
./deploy.sh validate
```

The routed application names are documented in [the route catalog](ROUTE_CATALOG.md). They use functional stack names such as `glpi`, `jenkins`, `mongodb` and `wordpress-blog`.

