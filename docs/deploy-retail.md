# Deploy Retail ERP

`retail.gavitotechnologies.com`, from `pardeep24/retail-cloud-erp`. Laravel (backend, queue,
Reverb, scheduler), MySQL, Redis and its own Caddy (`retail_cloud_prod_caddy`), in the Compose
project `infrastructure`. Stack file: [`stacks/retail.sh`](../stacks/retail.sh), plus
[`stacks/retail.edge.yml`](../stacks/retail.edge.yml), which takes away its public ports and
makes its Caddy answer plain HTTP on `:80` for the front proxy.

## Prerequisites

- The server is set up and this repository is at `/opt/gavito`.
- `env/gavito.env` has `GITHUB_TOKEN` with read access to `pardeep24/retail-cloud-erp`, and
  `RETAIL_HOSTS` lists every address the front proxy should send to retail.
- `env/retail.env` exists (below).
- The retail repository has the change that reads `RETAIL_SITE_ADDRESS` and trusts the front
  proxy's `X-Forwarded-*` headers (README, "Changes in the app repositories").

## Settings: `env/retail.env`

Linked to `run/retail/src/infrastructure/.env.production`. Start from the retail repository's
`infrastructure/.env.production.example`; on the current server, it is the existing file moved.

| Setting                                                | What it is                                          |
| ------------------------------------------------------ | --------------------------------------------------- |
| `APP_DOMAIN`, `APP_OLD_DOMAIN`                         | the address, and the old one still answered          |
| `APP_KEY`                                              | Laravel's encryption key. **Never change.**          |
| `DB_PASSWORD`, `DB_ROOT_PASSWORD`                      | MySQL passwords. **Never change.**                   |
| `REDIS_PASSWORD`                                       | Redis password                                      |
| `REVERB_APP_ID`, `REVERB_APP_KEY`, `REVERB_APP_SECRET` | live updates. The key is also built into the web app |
| `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM_ADDRESS`  | outgoing email                                      |

## Deploy a code update

```sh
cd /opt/gavito && git pull
./gavito deploy retail              # RETAIL_REF from versions.env (main)
./gavito deploy retail <commit>     # or a given version
```

This checks out the ref in `run/retail/src`, links the settings, runs `docker compose up -d
--build --remove-orphans` with `docker-compose.prod.yml` plus `retail.edge.yml`, and joins the
front proxy to `infrastructure_default`.

`./gavito deploy retail` does **not** back up the database. Before a deploy with a migration,
take one by hand:

```sh
docker exec retail_cloud_prod_backend php artisan backup:database
```

It writes to `storage/app/backups` in the `backend_storage` volume. The scheduler also takes one
every day at 02:00.

## Database changes

Laravel migrations in `backend/database/migrations/` of the retail repository. Create one with
`php artisan make:migration <name>` in `backend/`, merge it to `main`, then `./gavito deploy
retail`. The backend container runs `php artisan migrate --force` (and caches config, routes and
views) every time it starts; only the backend has `RUN_MIGRATIONS=true`, so queue, Reverb and the
scheduler never race it.

To see what has run, or to run pending migrations without a rebuild:

```sh
docker exec retail_cloud_prod_backend php artisan migrate:status
docker exec retail_cloud_prod_backend php artisan migrate --force
```

## Check it worked

```sh
./gavito status                                   # under "infrastructure": every container Up
docker logs --tail 50 retail_cloud_prod_backend   # migrations ran, no errors
docker exec retail_cloud_prod_backend php artisan migrate:status | tail -5
curl -fsS https://retail.gavitotechnologies.com/up
```

Then sign in, and check a screen that uses what changed.

## Roll back

**Code only:**

```sh
git -C /opt/gavito/run/retail/src log --oneline -5
./gavito deploy retail <previous-commit>
```

**A migration too:** undo it while the new code is still deployed (the rollback needs the
migration's `down()` method, which the older code doesn't have), then deploy the older version:

```sh
docker exec retail_cloud_prod_backend php artisan migrate:rollback --step=1 --force
./gavito deploy retail <previous-commit>
```

**Restore the database** from a backup, if data itself is damaged (this replaces the live
database):

```sh
docker exec retail_cloud_prod_backend ls storage/app/backups
docker exec retail_cloud_prod_backend php artisan backup:restore storage/app/backups/<file> \
  --database=retail_cloud --force --admin-password='<DB_ROOT_PASSWORD from env/retail.env>'
```

Without `--database` and `--force` it restores into a scratch database (`retail_cloud_restore_drill`)
instead, which is a safe way to look at a backup first.

Pin the good commit as `RETAIL_REF` in `versions.env` (or revert on `main`) so the next
`./gavito up` doesn't bring the bad version back.
