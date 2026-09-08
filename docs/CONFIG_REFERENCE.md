# Configuration Reference

## `nginx.conf`

This file controls global Nginx behavior:

- process and event configuration.
- HTTP includes.
- log format.
- global compression and proxy defaults.
- rate-limit zones if defined at HTTP scope.

Keep global behavior conservative. Route-specific exceptions should live in `conf.d/10-routes.conf` or snippets.

## `conf.d/00-http.conf`

Responsibilities:

- listen on port 80.
- serve ACME HTTP-01 challenges.
- redirect normal HTTP traffic to HTTPS.

This file is critical for renewal. Do not replace it with a redirect-only config unless ACME challenge paths are preserved.

## `conf.d/10-routes.conf`

Responsibilities:

- default HTTPS catch-all that returns `444`.
- status/health route.
- every production hostname.
- upstream service DNS and target port.
- route-specific snippet includes.

Rules:

- one hostname per server block unless there is a clear reason.
- use Swarm service names, not local Compose aliases.
- include TLS params on every HTTPS route.
- include security headers unless the app has a documented exception.
- protect infrastructure routes.

## `snippets/proxy-common.conf`

Shared proxy behavior should stay here:

- forwarded host and scheme.
- real client IP headers.
- HTTP version.
- upgrade behavior where needed.
- proxy buffering defaults.

Avoid duplicating common proxy headers in every route. Route-specific overrides can be added after this include.

## `snippets/security-headers.conf`

Default security header policy for normal applications.

Expected controls:

- HSTS.
- content type protection.
- frame policy.
- referrer policy.
- permissions policy.

## `snippets/security-headers-embed.conf`

Superset embedding can require a less restrictive frame policy. This file exists so the exception is visible and does not weaken all routes.

## `snippets/superset-cors.conf`

Superset has specific CORS and embedding behavior. Keep those rules isolated to avoid accidentally applying permissive CORS headers to infrastructure tools.

## `snippets/auth-infra.conf`

Basic auth snippet for infrastructure routes.

Depends on:

```text
/etc/nginx/auth/infra.htpasswd
```

The source file is `auth/infra.htpasswd`, ignored by Git.

## `snippets/ratelimit-infra.conf`

Shared rate limit and connection limit policy for internal tools.

Use this for:

- dashboards.
- admin tools.
- password/admin surfaces.
- services that should not receive uncontrolled traffic.

## `snippets/ssl-params.conf`

TLS policy for every HTTPS server block.

Do not edit casually. A TLS change affects every route.

## `certbot-domains.txt`

This is the hostname source of truth for certificate issuance.

Rules:

- keep it aligned with `conf.d/10-routes.conf`.
- remove hostnames that are not in DNS yet.
- review certificate expansion like a production change.

