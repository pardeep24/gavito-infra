# gavito-infra

Runs every Gavito Technologies product on one server with one command, and moves them all to a
new server with two. The apps' code stays in their own repositories; this repository holds only
what runs them together: the front proxy, each app's settings, and the `./gavito` script.

| App              | Repository                     | Addresses                                         |
| ---------------- | ------------------------------ | ------------------------------------------------- |
| Company website  | `pardeep24/a2zetechie`         | `gavitotechnologies.com`, `www.`                  |
| Retail ERP       | `pardeep24/retail-cloud-erp`   | `retail.gavitotechnologies.com`                   |
| Gavito Edu       | `pardeep24/school-saas`        | `edu.` and `staging.edu.gavitotechnologies.com`   |
| WhatsApp CRM     | `pardeep24/gavito-whatsapp-crm`| (not live yet)                                    |
| CRM Cafe         | `pardeep24/crm-cafe`           | `*.gavicatechnologies.cloud` (not in Docker yet)  |

```
Internet ── 80/443 ──> gavito-edge (Caddy, HTTPS for every address)
                         ├─> gavito-website:80            (website)
                         ├─> retail_cloud_prod_caddy:80   (retail's own Caddy → Laravel, Reverb)
                         ├─> school-saas-*-caddy-1:80     (Edu's own Caddy → API, web app)
                         └─> gavito-caddy:80              (WhatsApp CRM's own Caddy → web, API)
```

Only `gavito-edge` has public ports. Each app keeps its own Compose project, database and network,
so one app's deploy or failure can't touch another's data.

## On the server

```
/opt/gavito/                 this repository
  gavito                     the command
  versions.env               the branch or commit each app runs
  proxy/                     the front proxy: compose.yml, Caddyfile, sites/<app>.caddy
  stacks/<app>.sh            how each app is fetched, started and stopped
  env/<app>.env              each app's settings (server only, git-ignored)
  run/<app>/src              each app's code, fetched by ./gavito (server only)
  backups/                   snapshots (server only)
```

## Commands

```sh
./gavito up                  # front proxy + every app, at versions.env
./gavito deploy retail       # one app; add a branch or commit to deploy that instead
./gavito status
./gavito proxy               # after editing proxy/sites/*.caddy
./gavito snapshot            # one archive with every database, upload and setting
./gavito restore <archive>   # on a new server
```

Each deploy uses the app's own release steps, so migrations run the way each app already runs
them: Edu's `provision` job, Retail's backend entrypoint, WhatsApp CRM's `migrate` service.

## Moving to a new server

1. On the old server: `./gavito snapshot`, then copy `backups/gavito-*.tar.enc` off it.
2. On the new server, as root: clone this repository to `/opt/gavito`, run
   `./scripts/bootstrap-server.sh`, and put `env/gavito.env` back (it is in the snapshot too, but
   the passphrase and GitHub token are needed first).
3. `SNAPSHOT_PASSPHRASE=... ./gavito restore <archive>`, then `./gavito up`.
4. Point every DNS A record at the new server. The certificates come along in the snapshot, so
   HTTPS works as soon as DNS does.

`./gavito snapshot` stops every app for the few minutes the copy takes, so every database is
copied consistently. Run it at a quiet hour. Each app's own nightly backups keep running as before.

## Changes in the app repositories

`./gavito` needs a few small changes in the apps, each in its own pull request:

- **Retail:** read the Caddy site address from `RETAIL_SITE_ADDRESS` (default: today's
  `APP_DOMAIN APP_OLD_DOMAIN`), drop the Edu and website sites from its Caddyfile (they are in
  `proxy/sites/` now), trust the front proxy's `X-Forwarded-*` headers in Laravel, and make its
  deploy job run `./gavito deploy retail`.
- **Gavito Edu:** let `deploy-on-server.sh` take its folders from `SCHOOL_SRC` and
  `SCHOOL_APP_ROOT` (today `/opt/school-saas-src` and `/opt/school-saas-<target>`).
- **Website and WhatsApp CRM:** nothing required. WhatsApp CRM's settings point it at the
  `gavito-edge` network (`env/README.md`).
- **Cafe:** Dockerfiles for the API, Celery worker and web app, a production compose file, and a
  single Alembic migration head. Then `stacks/cafe.sh` and `proxy/sites/cafe.caddy` are switched on.

## Switching the current server over

The current server already runs everything except Cafe, with Retail's Caddy holding ports 80/443.
The switch, once the app changes above are merged:

1. Clone this repository to `/opt/gavito`, move each app's settings file into `env/` and Edu's
   `backups/` folders into `run/school/school-saas-*/`
   (`env/README.md` says which). Nothing is regenerated.
2. `./gavito deploy` each app. Each one comes up next to the running copy's data, because the
   Compose project and volume names stay the same.
3. The only moment visitors can notice: stop Retail's Caddy from holding 80/443 and start
   `gavito-edge` (`./gavito proxy`). A few seconds of downtime. To undo it, run Retail's previous
   compose file again.
4. Remove the old folders (`/opt/school-saas-*`, `/home/gavin/apps/*`) once every site checks out.
