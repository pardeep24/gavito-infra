# Deploy CRM Cafe

`food.gavitotechnologies.com`, `app.food.`, each cafe's `<slug>.food.` storefront and verified
custom domains, from `pardeep24/CRM-Cafe`. PostgreSQL, Redis, a `migrate` job, the FastAPI API,
the Celery worker, the Next.js web app and its own Caddy (`crm-cafe-web:80`), in the Compose
project `crm-cafe`. Stack file: [`stacks/cafe.sh`](../stacks/cafe.sh).

## Prerequisites

- The server is set up and this repository is at `/opt/gavito`.
- `env/gavito.env` has `GITHUB_TOKEN` with read access to `pardeep24/CRM-Cafe`.
- `env/cafe.env` exists (below).
- DNS has both `food` and `*.food` pointing at the server. Storefront certificates are issued on
  the first visit, once Cafe's `/api/public/tls-allowed` check says the host belongs to a cafe
  (`proxy/Caddyfile`), so the front proxy needs Cafe running to issue them.

## Settings: `env/cafe.env`

Linked to `run/cafe/src/deploy/.env`. Start from the Cafe repository's `deploy/.env.example`.

| Setting                                              | What it is                                            |
| ---------------------------------------------------- | ----------------------------------------------------- |
| `CAFE_DOMAIN`                                        | `food.gavitotechnologies.com`. Built into the web app |
| `POSTGRES_PASSWORD`                                  | database password. **Never change.**                  |
| `SECRET_KEY`                                         | signs sign-in tokens                                  |
| `SUPER_ADMIN_CODE`                                   | code for platform admin access                        |
| `ADMIN_BOOTSTRAP_EMAIL`, `ADMIN_BOOTSTRAP_PASSWORD`  | the first admin account (optional)                    |
| `STRIPE_SECRET_KEY`, `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `BILLING_CURRENCY` | payments (optional)          |
| `HTTP_PORT`                                          | the local check port, `127.0.0.1:8092` by default     |

## Deploy a code update

```sh
cd /opt/gavito && git pull
./gavito deploy cafe                # CAFE_REF from versions.env (main)
./gavito deploy cafe <commit>       # or a given version
```

This checks out the ref in `run/cafe/src`, links the settings, runs `docker compose up -d --build
--remove-orphans` with `deploy/docker-compose.yml`, and joins the front proxy to
`crm-cafe_default`. The `migrate` job runs `alembic upgrade head`; the API and the worker start
only once it succeeds.

`./gavito deploy cafe` does **not** back up the database. Before a deploy with a migration, take
one by hand:

```sh
cd /opt/gavito/run/cafe/src/deploy
mkdir -p ~/backups/cafe
docker compose exec -T postgres pg_dump -U cafe -d crm_cafe | gzip > ~/backups/cafe/crm_cafe-$(date -u +%Y%m%dT%H%M%SZ).sql.gz
```

## Database changes

Alembic migrations in `backend/alembic/versions/` of the Cafe repository, one file per change,
each naming the one before it (`down_revision`). Files are numbered, for example
`038_my_change.py` after `037_aggregator_orders.py`. Create one in `backend/` with
`alembic revision -m "my change"` (rename it to the next number and set `revision` to match),
write `upgrade()` and `downgrade()`, merge to `main`, then `./gavito deploy cafe`.

To see where the database is, or to migrate without a rebuild:

```sh
cd /opt/gavito/run/cafe/src/deploy
docker compose run --rm migrate alembic current
docker compose run --rm migrate
```

## Check it worked

```sh
./gavito status                                       # under "crm-cafe": every container Up
cd /opt/gavito/run/cafe/src/deploy
docker compose logs migrate                           # Alembic's "Running upgrade …" lines
docker compose logs --tail 50 api worker
curl -fsS https://food.gavitotechnologies.com/health
```

Then open a cafe's storefront and place a test order.

## Roll back

**Code only:**

```sh
git -C /opt/gavito/run/cafe/src log --oneline -5
./gavito deploy cafe <previous-commit>
```

**A migration too:** downgrade while the new code is still deployed (the downgrade lives in the
new migration file, which the older code doesn't have), then deploy the older version:

```sh
cd /opt/gavito/run/cafe/src/deploy
docker compose run --rm migrate alembic downgrade -1
cd /opt/gavito && ./gavito deploy cafe <previous-commit>
```

**Restore the database** from a dump, if data itself is damaged (this replaces all current data):

```sh
cd /opt/gavito/run/cafe/src/deploy
docker compose stop api worker
docker compose exec -T postgres psql -U cafe -d postgres \
  -c "drop database crm_cafe with (force)" -c "create database crm_cafe owner cafe"
gunzip -c ~/backups/cafe/crm_cafe-<time>.sql.gz | docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U cafe -d crm_cafe
cd /opt/gavito && ./gavito deploy cafe <previous-commit>
```

Pin the good commit as `CAFE_REF` in `versions.env` (or revert on `main`) so the next
`./gavito up` doesn't bring the bad version back.
