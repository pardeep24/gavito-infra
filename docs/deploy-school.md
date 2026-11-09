# Deploy Gavito Edu

`edu.gavitotechnologies.com` (live) and `staging.edu.gavitotechnologies.com`, from
`pardeep24/school-saas`. Two copies, each its own Compose project (`school-saas-staging`,
`school-saas-production`) with PostgreSQL (WAL-G backups), Redis, a `provision` job, the API, a
status page and its own Caddy. Live also runs ClamAV. Stack file:
[`stacks/school.sh`](../stacks/school.sh).

## How a deploy works

`./gavito deploy school` releases **staging first, then live with exactly the version staging now
runs**, in one go:

1. Checks out the ref (`SCHOOL_REF` from `versions.env`, or the one given) in `run/school/src`.
2. Copies the release script from the school repository's **`main`** branch
   (`infra/staging/deploy-on-server.sh`) to `run/school/deploy-on-server.sh`, whatever version is
   being released.
3. For staging, then live: links `env/school-<target>.env`, and runs the release script. It builds
   the web app in a throwaway Node container and the API image `school-saas-api:<commit>`, copies
   the stack files into `run/school/school-saas-<target>/`, and runs that copy's `deploy.sh`.
4. `deploy.sh` starts Postgres and Redis, runs the `provision` job (migrations), then starts the
   API and the rest with `--wait`, reloads its Caddy, and keeps the five newest API images. The
   release script then checks `/v1/health` and the web page on the copy's local port.

`SCHOOL_REF` is pinned to a commit in `versions.env`, so a plain `./gavito deploy school`
re-releases that commit. To put out new code, change `SCHOOL_REF` (and commit it here) or give a
ref.

## Prerequisites

- The server is set up and this repository is at `/opt/gavito`.
- `env/gavito.env` has `GITHUB_TOKEN` with read access to `pardeep24/school-saas`.
- `env/school-staging.env` and `env/school-production.env` exist (below).
- The school repository's `main` has `SCHOOL_APP_ROOT` support in its release script (the deploy
  stops with an error otherwise).

## Settings: `env/school-staging.env`, `env/school-production.env`

Linked to `run/school/school-saas-<target>/.env`. On the current server, each is the existing
`/opt/school-saas-<target>/.env` moved.

| Setting                                                              | What it is                                   |
| -------------------------------------------------------------------- | -------------------------------------------- |
| `APP_ENV`, `APP_BASE_DOMAIN`                                         | `staging`/`production` and the copy's address |
| `STAGING_PORT`, `STATUS_PORT`, `STATUS_PRODUCT`                      | local ports for checks, and the status page name (live: 8082, 8083) |
| `DNS_DRIVER`, `SMS_DRIVER`, `EMAIL_DRIVER`, `FILE_SCANNING`          | providers; live scans uploads with `clamav`  |
| `FRONT_PROXY_CONTAINER`                                              | **`gavito-edge`** on this server             |
| `POSTGRES_PASSWORD`, `API_DB_PASSWORD`, `AUTH_SECRET`, `REDIS_PASSWORD` | added on the first deploy. **Never change.** |
| `BACKUP_ENCRYPTION_KEY`                                              | added on the first deploy. **Keep a copy off the server**: backups can't be read without it. |
| `SENTRY_DSN`                                                         | error tracking (optional)                    |

## Deploy a code update

**Both copies at once** (the version must already be good on staging):

```sh
cd /opt/gavito && git pull
./gavito deploy school <commit>
```

**Staging first, live later** (recommended for anything with a migration). Run the release script
`./gavito` already put in place:

```sh
cd /opt/gavito
export SCHOOL_SRC=/opt/gavito/run/school/src SCHOOL_APP_ROOT=/opt/gavito/run/school
run/school/deploy-on-server.sh staging <commit-or-branch>
# … try it on https://staging.edu.gavitotechnologies.com …
run/school/deploy-on-server.sh production          # takes the version staging runs
```

Then set `SCHOOL_REF` in `versions.env` to that commit and commit it, so `./gavito up` keeps it.

## Database changes

Drizzle migrations in `apps/api/drizzle/` of the school repository (`NNNN_name.sql` plus
`drizzle/meta/`). Change `apps/api/src/db/schema.ts`, then generate the migration with
`pnpm --filter @school-saas/api db:generate`, check the SQL, and merge both. On deploy, the
`provision` job applies pending migrations as the database owner, then sets up the API's own role,
before the new API starts. If it fails, `deploy.sh` stops and the old API keeps running.

Staging gets every migration first, so a bad one shows up there before live.

## Check it worked

```sh
./gavito status                          # school-saas-staging and -production, every container Up
docker logs --tail 50 school-saas-production-api-1
docker inspect school-saas-production-api-1 --format '{{.Config.Image}}'   # the released commit
curl -fsS https://edu.gavitotechnologies.com/v1/health
curl -fsS https://staging.edu.gavitotechnologies.com/v1/health
```

The old `school.` addresses keep answering `/v1/*` for older phone apps (`proxy/sites/school.caddy`).

## Roll back

**Code only:** release the previous commit. Its API image is usually still on the server (the
five newest are kept).

```sh
docker images school-saas-api                       # tags are short commits
export SCHOOL_SRC=/opt/gavito/run/school/src SCHOOL_APP_ROOT=/opt/gavito/run/school
run/school/deploy-on-server.sh production <previous-commit>
```

Migrations are not undone by this; Edu's migrations only add, so older code normally runs on the
newer schema.

**Restore the database** to a minute before the bad release (point-in-time, from WAL-G). The API
stops while it runs, and the current database is saved first in
`backups/pre-restore-<time>.tar.gz`, so the restore can itself be undone:

```sh
cd /opt/gavito/run/school/school-saas-production
# Compose needs the running API's version to read this folder's compose file.
export API_TAG=$(docker inspect school-saas-production-api-1 --format '{{.Config.Image}}' | cut -d: -f2)
./restore.sh '2026-11-09 13:15'          # India time
./restore.sh latest                      # everything up to the last backed-up change
```

A nightly full backup runs on its own (the `backup` service, kept 30 days). Take one by hand
before a risky release, in the copy's folder, with `API_TAG` set as above:
`docker compose exec backup backup nightly`.

Pin the good commit as `SCHOOL_REF` in `versions.env` so the next `./gavito up` doesn't bring the
bad version back.
