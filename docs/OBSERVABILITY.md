# Observability

## What To Observe

The edge should answer four questions quickly:

1. Is Nginx running?
2. Are certificates valid and renewing?
3. Are routes reaching upstream services?
4. Are users receiving abnormal 4xx or 5xx responses?

## Logs

Nginx logs are stored in:

```text
nginx-logs
```

Runtime commands:

```bash
docker service logs nginx_nginx --tail 200
docker service logs nginx_certbot --tail 200
```

Important patterns:

- `host not found in upstream`
- `connect() failed`
- `upstream timed out`
- `no live upstreams`
- certificate renewal failures in Certbot output.

## Health Endpoints

The route `edge-status.example.com` is repurposed as an edge status route.

Checks:

```bash
curl -Ik https://edge-status.example.com/healthz
curl -Ik https://edge-status.example.com/nginx_status
```

`/nginx_status` is protected by basic auth.

## Suggested Alerts

| Alert | Why |
| --- | --- |
| Nginx service has zero running tasks | edge is down |
| Certbot renewal error | future TLS outage |
| certificate expires in less than 14 days | renewal may be broken |
| high 5xx rate | upstream or proxy issue |
| high 401/403 on admin routes | possible brute-force or misconfiguration |
| Docker node disk high | certificates/logs/volumes at risk |

## Certificate Expiry Check

```bash
host=edge-status.example.com
openssl s_client -connect "$host:443" -servername "$host" </dev/null 2>/dev/null \
  | openssl x509 -noout -dates -issuer -subject
```

## Upstream Reachability Check

```bash
container="$(docker ps --filter name=nginx_nginx -q | head -n 1)"
docker exec "$container" getent hosts jenkins_jenkins
docker exec "$container" wget -S -O /dev/null http://jenkins_jenkins:8080/login
```

## Future Improvements

- ship access logs to Loki or another log backend.
- add Prometheus Nginx exporter.
- alert on certificate expiry.
- build a synthetic check per public hostname.
- track response code rates per route.

