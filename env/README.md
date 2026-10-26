# env/

One settings file per app, all in this folder so a server move copies them together. Real files
(`*.env`) live only on the server and are git-ignored; `./gavito` links each one to the path its
app expects.

| File                      | App                  | Linked to                                         | Start from                                                       |
| ------------------------- | -------------------- | ------------------------------------------------- | ---------------------------------------------------------------- |
| `gavito.env`              | ./gavito itself      | (read directly)                                   | `gavito.env.example`                                             |
| `website.env`             | Company website      | `run/website/src/.env`                            | the website repo's `.env.example`                                |
| `retail.env`              | Retail ERP           | `run/retail/src/infrastructure/.env.production`   | the retail repo's `infrastructure/.env.production.example`       |
| `school-staging.env`      | Gavito Edu staging   | `run/school/school-saas-staging/.env`             | the staging server's current `/opt/school-saas-staging/.env`     |
| `school-production.env`   | Gavito Edu live      | `run/school/school-saas-production/.env`          | the server's current `/opt/school-saas-production/.env`          |
| `whatsapp.env`            | WhatsApp CRM         | `run/whatsapp/src/deploy/.env`                    | the WhatsApp repo's `deploy/setup.sh` output                     |

On the current server, each file is the app's existing settings file moved here, so nothing is
regenerated: Retail's `APP_KEY` and Edu's database passwords must never change.

For Gavito Edu, set `FRONT_PROXY_CONTAINER=gavito-edge` in both `school-*.env` files (today it is
`retail_cloud_prod_caddy`).

For WhatsApp CRM behind the front proxy, `whatsapp.env` also needs:

```sh
COMPOSE_FILE=docker-compose.yml:docker-compose.behind-proxy.yml:docker-compose.proxy-network.yml
PROXY_NETWORK=gavito-edge
```
