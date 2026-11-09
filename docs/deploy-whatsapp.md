# Deploy WhatsApp CRM

`crm.gavitotechnologies.com`, from `pardeep24/gavito-whatsapp-crm`. PostgreSQL, a `migrate` job,
the Next.js web app, the webhook API and its own Caddy, in the Compose project `gavito`. Its Caddy
joins the `gavito-edge` network as `gavito-caddy:80`, where the front proxy reaches it. Stack
file: [`stacks/whatsapp.sh`](../stacks/whatsapp.sh).

## Prerequisites

- The server is set up (`scripts/bootstrap-server.sh`) and this repository is at `/opt/gavito`.
  The bootstrap script also writes the nightly database backup job (`/etc/cron.d/gavito-backup`,
  02:30, kept 14 days).
- `env/gavito.env` has `GITHUB_TOKEN` with read access to `pardeep24/gavito-whatsapp-crm`.
- `env/whatsapp.env` exists (below).
- DNS for `crm.gavitotechnologies.com` points at the server.

## Settings: `env/whatsapp.env`

Linked to `run/whatsapp/src/deploy/.env`. It is the file the app's own `deploy/setup.sh` writes;
on this server it also needs the two lines that put it behind the front proxy:

```sh
COMPOSE_FILE=docker-compose.yml:docker-compose.behind-proxy.yml:docker-compose.proxy-network.yml
PROXY_NETWORK=gavito-edge
```

| Setting                                                     | What it is                                              |
| ----------------------------------------------------------- | ------------------------------------------------------- |
| `DOMAIN`, `ACME_EMAIL`                                      | `crm.gavitotechnologies.com` and the certificate email  |
| `BREVO_API_KEY` or `SMTP_URL`, `EMAIL_FROM`                 | how sign-in and notification emails are sent            |
| `POSTGRES_PASSWORD`, `APP_DB_PASSWORD`                      | database owner and app passwords. **Never change.**     |
| `AUTH_SECRET`                                               | signs sign-in sessions                                  |
| `WHATSAPP_TOKEN_KEY`                                        | encrypts stored WhatsApp tokens. **Lose it and every number must be reconnected.** |
| `META_WEBHOOK_VERIFY_TOKEN`                                 | the token Meta's webhook setup asks for                 |
| `META_APP_ID`, `META_APP_SECRET`, `META_EMBEDDED_SIGNUP_CONFIG_ID`, `META_GRAPH_VERSION` | the Meta app. The webhook API (`api`) only starts once `META_APP_SECRET` is set. |
| `HTTP_PORT`                                                 | the local check port, `127.0.0.1:8091` by default       |

## Deploy a code update

```sh
cd /opt/gavito && git pull
./gavito deploy whatsapp            # WHATSAPP_REF from versions.env (main)
./gavito deploy whatsapp <commit>   # or a given version
```

In order, this:

1. Checks out the ref in `run/whatsapp/src`.
2. Links `env/whatsapp.env` to `deploy/.env`.
3. If Postgres is running, takes a database backup with the app's `deploy/backup.sh`
   (`run/whatsapp/src/deploy/backups/gavito-<time>.sql.gz`).
4. Runs the app's `deploy/up.sh`: `docker compose build --pull`, then `docker compose up -d
   --remove-orphans`. The `migrate` job runs first; `web` and `api` start only once it succeeds.

## Database changes

Migrations are plain SQL files in `packages/db/migrations/` of the app repository, named
`NNNN_short_name.sql` (four digits, lower case). To change the schema:

1. Add the next number, for example `0017_my_change.sql` after `0016_webhooks.sql`.
2. Merge it to `main` with the code that needs it.
3. `./gavito deploy whatsapp`.

The `migrate` job applies every file not yet listed in the `schema_migrations` table, in name
order, each in its own transaction, under a lock so two deploys can't apply one twice. A file that
fails is rolled back and the deploy stops before the new app starts, so the old version keeps
running. **Never edit a file that has already been deployed**: it won't run again. Write a new one.

To run the migrations alone, without a rebuild:

```sh
cd /opt/gavito/run/whatsapp/src/deploy && docker compose run --rm migrate
```

## Check it worked

```sh
./gavito status                                   # under "gavito": postgres, web, api, caddy Up
cd /opt/gavito/run/whatsapp/src/deploy
docker compose logs migrate                       # "Applied: 0017_…" or "Database is up to date"
docker compose logs --tail 50 web api
curl -fsS http://127.0.0.1:8091/ >/dev/null && echo ok
```

Then sign in at `https://crm.gavitotechnologies.com` and send a test message.

## Roll back

**Code only** (no migration in the bad version, or the migration is harmless to older code):

```sh
git -C /opt/gavito/run/whatsapp/src log --oneline -5
./gavito deploy whatsapp <previous-commit>
```

**Code and database** (a migration broke data or older code can't run on the new schema). There
are no down migrations, so put back the backup the deploy took. This replaces all current data
with the backup's, so anything written since is lost:

```sh
cd /opt/gavito/run/whatsapp/src/deploy
ls -t backups/ | head -3                          # the newest is the one taken before the deploy
docker compose --profile whatsapp stop web api
docker compose exec -T postgres psql -U gavito_owner -d postgres \
  -c "drop database gavito with (force)" -c "create database gavito"
gunzip -c backups/gavito-YYYYMMDDTHHMMSSZ.sql.gz \
  | docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U gavito_owner -d gavito
cd /opt/gavito && ./gavito deploy whatsapp <previous-commit>
```

Pin the good commit as `WHATSAPP_REF` in `versions.env` (or revert on `main`) so the next
`./gavito up` doesn't bring the bad version back.

Take a backup by hand any time with `run/whatsapp/src/deploy/backup.sh`. Copy backups off the
server too.
