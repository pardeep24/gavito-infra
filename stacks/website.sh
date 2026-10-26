# Company website, gavitotechnologies.com (pardeep24/a2zetechie). One PHP + Apache container.
WEBSITE_REPO=pardeep24/a2zetechie
WEBSITE_SRC="$RUN_DIR/website/src"

website_compose() { docker compose --project-directory "$WEBSITE_SRC" -f "$WEBSITE_SRC/docker-compose.yml" "$@"; }

website_deploy() {
  checkout website "$WEBSITE_REPO" "${1:-$WEBSITE_REF}"
  link_env website "$WEBSITE_SRC/.env"
  website_compose up -d --build --remove-orphans
  edge_join gavito-website
}

website_start() { website_compose up -d --no-build; edge_join gavito-website; }
website_stop() { website_compose stop; }
website_projects() { echo gavito-website; }
website_networks() { echo gavito-website; }
