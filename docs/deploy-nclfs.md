# Deploy the NCLFS demo

`nclfns.gavitotechnologies.com`, from `pardeep24/nclfns-school-app`: a demo copy of the NCLFS
school app with demo data only (the real school runs on its own server in Canada). The Compose
project `nclfs-demo` (PostgreSQL, Redis, a `provision` job, the API, its own Caddy) runs in
`run/nclfs/nclfs-demo/`. Stack file: [`stacks/nclfs.sh`](../stacks/nclfs.sh).

## How a deploy works

1. Checks out the ref (`NCLFS_REF` from `versions.env`, or the one given) in `run/nclfs/src`.
2. Copies the app's `infra/nclfs/deploy-on-server.sh` to `run/nclfs/deploy-on-server.sh` and runs
   it as `deploy-on-server.sh demo <commit>`.
3. That builds the web app and the API image `school-saas-api:<commit>`, remembers the version
   now running (for rollback), copies the stack files, and runs `deploy.sh`: Postgres and Redis,
   the `provision` job (migrations), then the API. It writes the version to `.release-current`
   and checks `/v1/health` on the local port.
4. Joins the front proxy to `nclfs-demo_default`.

Only one NCLFS deploy runs at a time (a lock in the release script).

## Prerequisites

- The server is set up and this repository is at `/opt/gavito`.
- `env/gavito.env` has `GITHUB_TOKEN` with read access to `pardeep24/nclfns-school-app`.
- `env/nclfs-demo.env` exists, from [`env/nclfs-demo.env.example`](../env/nclfs-demo.env.example).
- DNS for `nclfns.gavitotechnologies.com` points at the server.

## Settings: `env/nclfs-demo.env`

Linked to `run/nclfs/nclfs-demo/.env`.

| Setting                                        | What it is                                        |
| ---------------------------------------------- | ------------------------------------------------- |
| `APP_ENV=staging`                              | demo data is refused on `production`              |
| `APP_BASE_DOMAIN`                              | `nclfns.gavitotechnologies.com`                   |
| `DNS_DRIVER=local`                             | one school on one address                         |
| `STAGING_PORT`, `STATUS_PORT`, `STATUS_PRODUCT`| local check ports (8094, 8095) and status name    |
| `FRONT_PROXY_CONTAINER=gavito-edge`            | the front proxy                                   |
| `BACKUP_TZ`                                    | time zone for backup times                        |
| `POSTGRES_PASSWORD`, `API_DB_PASSWORD`, `REDIS_PASSWORD`, `AUTH_SECRET`, `BACKUP_ENCRYPTION_KEY` | added on the first deploy. **Never change.** |

## Deploy a code update

```sh
cd /opt/gavito && git pull
./gavito deploy nclfs               # NCLFS_REF from versions.env (main)
./gavito deploy nclfs <commit>      # or a given version
```

Load the demo people and data (and the old nclfns.com site's public content) once, after the first
deploy. It is not part of deploy, so a redeploy keeps what people changed; run again, it only adds
what is new:

```sh
./gavito task nclfs demo_data       # sign in as director@example.com
```

## Database changes

The same as Gavito Edu: Drizzle migrations in `apps/api/drizzle/` of the NCLFS repository,
generated with `pnpm --filter @school-saas/api db:generate` from `apps/api/src/db/schema.ts`. The
`provision` job applies them on deploy before the new API starts.

## Check it worked

```sh
./gavito status                                 # under "nclfs-demo": every container Up
cat run/nclfs/nclfs-demo/.release-current       # the released commit
docker logs --tail 50 nclfs-demo-api-1
curl -fsS https://nclfns.gavitotechnologies.com/v1/health
```

## Roll back

The release script keeps the version before (`.release-previous`, plus its web build) and can put
it back:

```sh
cd /opt/gavito
NCLFS_SRC=/opt/gavito/run/nclfs/src NCLFS_DEMO_APP=/opt/gavito/run/nclfs/nclfs-demo \
  run/nclfs/deploy-on-server.sh rollback demo
```

If that version's image was removed, deploy a known-good commit instead:
`./gavito deploy nclfs <commit>`. The database keeps what newer migrations added (they only add).
It holds demo data only, so if it is damaged, the simplest fix is to load the demo data again.
