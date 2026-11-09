# Deploy guides

One guide per app. Each says what to have ready, which settings it needs, how to put out a code
update, how a database change gets applied, how to check it worked and how to go back.

| App             | Guide                                    | Database change applied by                         |
| --------------- | ---------------------------------------- | -------------------------------------------------- |
| Company website | [deploy-website.md](deploy-website.md)   | no database                                        |
| Retail ERP      | [deploy-retail.md](deploy-retail.md)     | `php artisan migrate --force` when the backend starts |
| Gavito Edu      | [deploy-school.md](deploy-school.md)     | the `provision` job (Drizzle), before the API starts |
| WhatsApp CRM    | [deploy-whatsapp.md](deploy-whatsapp.md) | the `migrate` service (numbered SQL files)         |
| CRM Cafe        | [deploy-cafe.md](deploy-cafe.md)         | the `migrate` service (`alembic upgrade head`)     |
| NCLFS demo      | [deploy-nclfs.md](deploy-nclfs.md)       | the `provision` job (Drizzle), before the API starts |

## The same for every app

Everything runs on the server as the `deploy` user, from `/opt/gavito`:

```sh
sudo -iu deploy
cd /opt/gavito
git pull                         # this repository: versions.env, proxy sites, stack files
./gavito deploy <app>            # the app at its ref in versions.env
./gavito deploy <app> <ref>      # or a branch, tag or commit for this one deploy
./gavito status                  # every container and its state
```

- **Always as `deploy`, never as root.** `/opt/gavito` belongs to `deploy`; git run as root stops
  with "detected dubious ownership". Don't add a `safe.directory` exception: root-run deploys
  leave root-owned files in `run/` and `env/` that later deploys can't change. If that has
  already happened, fix it once as root with `chown -R deploy:deploy /opt/gavito`.
- **A code update** is: merge the change to the app repository's deployed branch (normally
  `main`), then `./gavito deploy <app>`. `./gavito` fetches the code into `run/<app>/src`, checks
  out the ref, links `env/<app>.env` into place and runs the app's own build and release.
- **A database change** is a new migration file in the app repository, merged with the code that
  needs it. Every app applies pending migrations on deploy, before the new code takes traffic, so
  there is no separate migration step. Each guide says where migration files go.
- **A ref given on the command line is not remembered.** The next `./gavito up` goes back to
  `versions.env`. To keep an app on a version, put that commit in `versions.env`, commit it to
  this repository and `git pull` on the server.
- **Migrations only go forward on their own.** Deploying an older version does not undo a
  migration. Each guide says how to undo one, or how to restore the database.
- **Settings** live in `env/<app>.env` (see [../env/README.md](../env/README.md)). After changing
  one, run `./gavito deploy <app>` again so the containers pick it up.
- After editing `proxy/sites/*.caddy`, run `./gavito proxy`.
