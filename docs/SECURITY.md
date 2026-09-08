# Security

## Security Objective

The Nginx edge reduces accidental exposure by making every public route explicit. It centralizes TLS, authentication snippets, rate limiting, and headers in a small set of reviewed files.

## Secrets

Never commit:

- `auth/infra.htpasswd`
- `.env`
- certificate private keys.
- `acme.json` from any previous Traefik deployment.
- generated Let's Encrypt material.

The committed file `auth/infra.htpasswd.example` is only a placeholder.

## TLS

The edge allows TLS 1.2 and TLS 1.3 only. TLS settings live in `snippets/ssl-params.conf`.

Operational rules:

- ACME challenge must work over HTTP before expecting HTTPS to work.
- certificate renewal failures must be treated as incidents before expiry.
- unknown HTTPS hosts are closed with `444`.
- do not weaken ciphers to satisfy obsolete clients unless the business explicitly accepts the risk.

## Basic Auth

Infrastructure routes use `snippets/auth-infra.conf`. The runtime password file is mounted through Docker config.

Protected routes include administrative surfaces such as phpMyAdmin, Jenkins, selected WordPress admin/demo services, and the edge health/status route.

Generate a new bcrypt hash:

```bash
docker run --rm httpd:2.4 htpasswd -nbB admin 'new-password'
```

## Rate Limiting

`snippets/ratelimit-infra.conf` protects internal tools from uncontrolled request bursts. The values are high enough for normal use but still give the edge a guardrail against abuse or accidental loops.

Rate limiting is not a replacement for authentication. It is a second layer.

## Headers

The default security header snippet sets:

- HSTS.
- `X-Content-Type-Options`.
- frame policy.
- referrer policy.
- permissions policy.

Superset uses a separate embed-safe header snippet because embedded dashboards can conflict with strict frame rules. This exception is explicit and limited to the Superset route.

## Threat Model

| Threat | Control |
| --- | --- |
| Wrong Docker label exposes a service | Nginx has no dynamic route discovery |
| Credential leak through Git | real auth file and `.env` are ignored |
| Certificate expiry | Certbot sidecar renews every 12 hours |
| Upstream app crash | Nginx logs show upstream failures |
| Brute force on admin tools | basic auth and rate limits |
| Host header confusion | explicit server names and default `444` |

## Production Hardening Backlog

- add centralized log shipping.
- alert before certificate expiry.
- restrict admin routes by VPN or IP allowlist.
- split public and admin routes if the platform grows.
- consider per-route rate limits instead of one shared profile.
- add automated config tests in CI.

