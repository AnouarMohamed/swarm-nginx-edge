# Architecture Decisions

## ADR-001: Use Nginx As The Static Swarm Edge

Decision: replace dynamic Traefik label discovery with an explicit Nginx edge.

Reasoning:

- the route set is small enough to keep in one reviewed file.
- public exposure becomes obvious during code review.
- Nginx behavior is predictable and easy to debug from logs.
- the team can explain every public hostname without opening a dashboard.
- Nginx maps cleanly to a future Kubernetes Ingress model.

Tradeoff:

- adding or changing a route requires a config edit and redeploy.
- the edge no longer discovers services automatically.

Status: accepted.

## ADR-002: Keep The Existing `edge-net` Name

Decision: keep the default edge network named `edge-net`.

Reasoning:

- existing Swarm stacks are already attached to this network.
- the migration changes the edge only, not every application.
- rollback to Traefik remains simple because the shared network is unchanged.
- it reduces risk during a proxy migration.

Tradeoff:

- the network name no longer describes the active proxy.
- a future cleanup can move to `nginx-net` after all services are reviewed.

Status: accepted as a compatibility decision.

## ADR-003: Use A Two-Stage TLS Bootstrap

Decision: use `nginx.bootstrap.stack.yml` for first ACME issuance, then switch to the full HTTPS stack.

Reasoning:

- the full HTTPS config expects certificate files to exist.
- HTTP-01 challenge needs port 80 before HTTPS is available.
- the bootstrap stack is simple and temporary.
- the process is easy to explain and repeat.

Tradeoff:

- first deployment has more steps.
- operators must remember to remove the bootstrap stack.

Status: accepted.

## ADR-004: Use One SAN Certificate For The Edge

Decision: issue one certificate named `swarm-edge` containing the hostnames in `certbot-domains.txt`.

Reasoning:

- certificate operations are simple for a compact route set.
- renewal is centralized.
- all hostnames are reviewed in one file.
- Nginx config can reuse the same certificate path across routes.

Tradeoff:

- adding a host expands the shared certificate.
- a failed issuance can affect the update of the shared certificate.
- very large route sets may need per-domain certificates later.

Status: accepted for the current scale.

## ADR-005: Use Docker Config Hashing

Decision: version Docker config objects by hashing the actual files consumed by Nginx.

Reasoning:

- Swarm configs are immutable.
- a content hash forces a new config object when files change.
- the stack update becomes deterministic.
- the deployed config version is traceable from Git content.

Tradeoff:

- old Docker config objects can remain until cleaned.
- hash calculation must include every file that affects Nginx behavior.

Status: accepted.

## ADR-006: Keep Certbot As A Sidecar Service

Decision: run Certbot as a Swarm service that renews every 12 hours.

Reasoning:

- certificate lifecycle stays near the edge.
- Certbot can share the webroot and certificate volumes with Nginx.
- the renewal process is explicit and inspectable.
- Nginx reloads periodically to pick up renewed material.

Tradeoff:

- Nginx and Certbot coordination is manual through shared volumes.
- renewal logs must be monitored.

Status: accepted.

## ADR-007: Use Basic Auth For Infrastructure Routes

Decision: protect selected infrastructure routes with a shared htpasswd file.

Reasoning:

- phpMyAdmin, Jenkins, and status endpoints are not normal public websites.
- the protection is simple and works at the edge.
- one file can be rotated and redeployed.
- application-level auth remains necessary, but edge auth reduces exposure.

Tradeoff:

- shared credentials are less granular than per-user identity.
- production should consider VPN, SSO, or IP allowlists.

Status: accepted as a practical baseline.

