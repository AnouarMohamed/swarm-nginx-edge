# Runbooks

## 1. Edge Down

```bash
docker service ls
docker service ps nginx_nginx
docker service logs nginx_nginx --tail 200
```

Check:

- ports 80 and 443 are not already owned by another stack.
- Nginx config is valid.
- certificate files exist.
- service is attached to the edge network.

## 2. Certificate Failed

```bash
docker service logs nginx_certbot --tail 200
curl -I http://<host>/.well-known/acme-challenge/test
```

Recovery:

1. verify DNS points to the server.
2. deploy bootstrap config if first issuance.
3. remove hostnames from `certbot-domains.txt` if they are not ready.
4. run `./deploy.sh certs`.
5. redeploy full edge.

## 3. One Route Returns 502

```bash
docker service ls
docker service ps <stack>_<service>
docker service logs <stack>_<service> --tail 100
docker exec $(docker ps --filter name=nginx_nginx -q | head -n 1) getent hosts <stack>_<service>
```

Most common causes:

- upstream service name is wrong.
- service is not attached to the edge network.
- target container port is wrong.
- app task is restarting or unhealthy.

## 4. Basic Auth Broken

```bash
ls -l auth/infra.htpasswd
docker run --rm httpd:2.4 htpasswd -nbB admin 'new-password'
./deploy.sh deploy
```

Remember that Docker configs are immutable. A changed auth file must produce a new config hash and redeploy.

## 5. Emergency Rollback To Traefik

Use only if the Nginx edge cannot be restored quickly.

```bash
./deploy.sh rm
cd ../swarm-traefik-platform/traefik
./deploy.sh
```

Then validate the Traefik dashboard and public routes.

## 6. Pre-Push Safety Check

```bash
bash -n deploy.sh scripts/*.sh
rg -n "BEGIN|PRIVATE KEY|password=|PASSWORD=|token=|TOKEN=|acme|htpasswd" .
git status --short
```

Real secrets must not appear in tracked files.

## 7. Restore From No Certificate State

Use when the certificate volume is missing or corrupted.

```bash
docker volume create nginx-letsencrypt || true
docker volume create nginx-certbot-webroot || true
./deploy.sh bootstrap
./deploy.sh certs
./deploy.sh rm-bootstrap
./deploy.sh deploy
```

If issuance fails, remove unready hostnames from `certbot-domains.txt` and retry.

## 8. Rotate Infrastructure Password

```bash
docker run --rm httpd:2.4 htpasswd -nbB admin 'new-password'
```

Replace the content of `auth/infra.htpasswd`, then:

```bash
./deploy.sh deploy
curl -Ik https://db-admin.example.com/
```

Expected result: browser or curl receives a basic-auth challenge and old credentials no longer work.

## 9. Validate Every Public Route

```bash
while read -r host; do
  [ -z "$host" ] && continue
  echo "== $host =="
  curl -Ik --max-time 10 "https://$host/" | sed -n '1,8p'
done < certbot-domains.txt
```

Protected routes may return `401`; that is expected.

## 10. Clean Old Docker Configs

Swarm configs are immutable, so old config versions can remain after repeated deploys.

List:

```bash
docker config ls | rg '^.*nginx'
```

Remove only configs not referenced by the current service:

```bash
docker service inspect nginx_nginx --format '{{json .Spec.TaskTemplate.ContainerSpec.Configs}}'
docker config rm <old_config_name>
```
