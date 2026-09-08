# Production Readiness

## Readiness Position

This repo is a strong Swarm edge baseline. Production readiness depends on operational controls around it: monitoring, backup, access control, DNS discipline, and incident response.

## Matrix

| Area | Current repo | Production expectation |
| --- | --- | --- |
| routes | explicit server blocks | reviewed route ownership and owner list |
| TLS | Certbot sidecar and SAN certificate | expiry alerts and renewal incident runbook |
| auth | shared htpasswd file | rotated credentials, possibly VPN/SSO/IP allowlist |
| logging | Nginx log volume | shipped logs and retention policy |
| rollback | Git revert and redeploy | tested rollback drill |
| secrets | ignored runtime files | secure backup and rotation process |
| upstream health | manual checks | synthetic checks per hostname |
| network | shared edge overlay | documented service attachment policy |
| deployment | idempotent script plus containerized preflight | CI invocation and controlled release approval |
| supply chain | Nginx and Certbot pinned by version and digest | scheduled vulnerability review and deliberate pin updates |

## High-Priority Improvements

- add certificate expiry alerting.
- add external monitoring for every route.
- restrict infrastructure routes beyond basic auth.
- centralize logs.
- document route owners.
- test restoring `nginx-letsencrypt` volume.
- test full bootstrap from no certificate state.

## Route Ownership

Every route should have:

- service owner.
- upstream stack and service.
- protection level.
- backup owner if stateful.
- rollback method.
- acceptable downtime.

## Production Gate

Do not promote a new route until:

1. DNS resolves correctly.
2. upstream service is healthy.
3. route protection is chosen.
4. certificate issuance succeeds.
5. HTTP and HTTPS validation pass.
6. rollback is clear.
7. monitoring is updated.

## Edge Failure Impact

The edge is a single public entrypoint. If it is down, all public services behind it are effectively down, even if the app containers are healthy. Treat the edge as critical infrastructure.
