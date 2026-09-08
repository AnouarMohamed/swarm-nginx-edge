# Change Management

## Change Classes

| Change type | Risk | Review expectation |
| --- | --- | --- |
| documentation only | low | normal review |
| add public route | medium | route, DNS, TLS, upstream, auth review |
| change upstream port/name | medium/high | service owner validation |
| change TLS params | high | full edge review |
| change auth file behavior | high | security review |
| change rate limits | medium | traffic impact review |
| switch edge network | high | all app stacks must be checked |

## Standard Workflow

```bash
git status --short
bash -n deploy.sh scripts/*.sh
git diff
./deploy.sh deploy
curl -Ik https://edge-status.example.com/healthz
```

For a new hostname:

```bash
./deploy.sh certs
./deploy.sh deploy
```

## Pre-Change Checklist

- Is the Git tree clean?
- Is there a rollback commit?
- Is DNS ready?
- Is the upstream service running?
- Is the upstream attached to the edge network?
- Does the route need auth?
- Does the route need larger upload limits?
- Does the route need WebSocket headers?
- Is the hostname in `certbot-domains.txt`?

## Post-Change Checklist

- `docker service ps nginx_nginx` is healthy.
- `docker service logs nginx_nginx` has no config errors.
- `nginx -t` passes inside the container.
- HTTP redirects as expected.
- HTTPS certificate is valid.
- route reaches the intended app.
- protected route challenges for auth.

## Rollback Model

The clean rollback is:

```bash
git revert <bad_commit>
./deploy.sh deploy
```

For a certificate expansion failure, rollback may mean removing the new hostname from `certbot-domains.txt`, reissuing with the known-good set, and redeploying.

## Why This Matters

The edge is a small layer with high blast radius. A one-line route error can affect a public service. Change management keeps that risk visible.

