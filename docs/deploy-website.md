# Deploy the company website

`gavitotechnologies.com` and `www.`, from `pardeep24/a2zetechie`. One PHP + Apache container
(`gavito-website`), no database. Stack file: [`stacks/website.sh`](../stacks/website.sh).

## Prerequisites

- The server is set up (`scripts/bootstrap-server.sh`) and this repository is at `/opt/gavito`.
- `env/gavito.env` has `GITHUB_TOKEN` (read access to `pardeep24/a2zetechie`) and `ACME_EMAIL`.
- `env/website.env` exists.
- DNS for `gavitotechnologies.com` and `www.` points at the server.

## Settings: `env/website.env`

Linked to `run/website/src/.env` and passed to the container as is. Start from the website
repository's `.env.example`:

| Setting                                                   | What it is                                  |
| --------------------------------------------------------- | ------------------------------------------- |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`    | the mail server the contact form sends with |
| `SMTP_FROM`, `SMTP_FROM_NAME`                             | the sender of those emails                  |
| `CONTACT_TO`                                              | where contact form messages go              |
| `SITE_INDEXABLE`                                          | whether search engines may index the site   |

## Deploy a code update

```sh
cd /opt/gavito && git pull
./gavito deploy website            # WEBSITE_REF from versions.env (main)
./gavito deploy website <commit>   # or a given version
```

This checks out the ref in `run/website/src`, links the settings, runs
`docker compose up -d --build --remove-orphans` with the website's own `docker-compose.yml`, and
joins the front proxy to the `gavito-website` network.

## Database changes

None: the website has no database.

## Check it worked

```sh
./gavito status                                   # gavito-website is Up
curl -fsS http://127.0.0.1:8090/ | head -5        # straight to the container
curl -fsSI https://gavitotechnologies.com/        # through the front proxy
```

Send a message through the contact form to check the mail settings.

## Roll back

```sh
git -C run/website/src log --oneline -5           # find the version before
./gavito deploy website <that-commit>
```

If the bad version is on `main`, revert it in the website repository too, or pin the good commit
as `WEBSITE_REF` in `versions.env`, so the next `./gavito up` doesn't bring it back.
