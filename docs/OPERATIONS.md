# Operations

## Operator Contract

The Nginx edge operator is responsible for:

- DNS correctness.
- valid certificates.
- route correctness.
- service attachment to the edge network.
- safe redeploys after config changes.
- keeping the auth file outside Git.

## Deployment Modes

| Command | Purpose |
| --- | --- |
| `./deploy.sh bootstrap` | deploy temporary HTTP-only Nginx for first ACME challenge |
| `./deploy.sh certs` | issue or expand the SAN certificate with Certbot |
| `./deploy.sh rm-bootstrap` | remove bootstrap stack |
| `./deploy.sh deploy` | deploy the full HTTPS edge |
| `./deploy.sh renew` | force renewal attempt and restart Nginx |
| `./deploy.sh rm` | remove the Nginx stack |

## First Deployment Flow

```text
DNS -> bootstrap Nginx on port 80 -> Certbot HTTP-01 -> full Nginx on 80/443 -> renewal sidecar
```

Commands:

```bash
./deploy.sh bootstrap
./deploy.sh certs
./deploy.sh rm-bootstrap
./deploy.sh deploy
```

Do not deploy the full HTTPS stack before a certificate exists. The full config expects the certificate path to be present.

## Adding A Route

1. Confirm the app service exists:

   ```bash
   docker service ls
   ```

2. Confirm the app service is attached to the edge network:

   ```bash
   docker service inspect <stack>_<service> --format '{{json .Spec.TaskTemplate.Networks}}'
   ```

3. Add the hostname to `certbot-domains.txt`.
4. Add a `server` block in `conf.d/10-routes.conf`.
5. Use shared snippets unless the service has a reason not to.
6. Run:

   ```bash
   ./deploy.sh certs
   ./deploy.sh deploy
   ```

7. Validate:

   ```bash
   curl -I http://<host>/
   curl -Ik https://<host>/
   ```

## Config Versioning

`deploy.sh` hashes the relevant config files and exports `NGINX_CONFIG_VERSION`. The stack file uses that value to create versioned Docker config objects.

Why this matters:

- Docker Swarm config objects are immutable.
- a content hash makes redeploys deterministic.
- old config objects can coexist during rollout.
- a route change reliably produces a new config name.

## Certificate Operations

The repo uses one SAN certificate named `swarm-edge`. This keeps certificate management simple for a compact platform.

Check certificate status:

```bash
docker service logs nginx_certbot --tail 100
docker run --rm -v nginx-letsencrypt:/etc/letsencrypt alpine \
  find /etc/letsencrypt/live -maxdepth 2 -type f
```

Force renewal:

```bash
./deploy.sh renew
```

## Rollback

Rollback is a Git operation plus a stack redeploy:

```bash
git revert <bad_commit>
./deploy.sh deploy
```

If the edge is severely broken and Traefik is still available, the emergency rollback is to stop Nginx and redeploy Traefik. Only one edge can bind ports 80 and 443 at a time.

## Monitoring

Minimum checks:

```bash
docker service ls
docker service ps nginx_nginx
docker service logs nginx_nginx --tail 100
docker service logs nginx_certbot --tail 100
curl -Ik https://edge-status.example.com/
```

Useful signals:

- 4xx and 5xx trends in Nginx logs.
- certificate renewal failures.
- upstream resolution errors.
- failed auth attempts on infrastructure routes.
- service tasks restarting behind the edge.

