# shellcheck shell=bash
# Retail Cloud ERP, retail.gavitotechnologies.com (pardeep24/retail-cloud-erp).
# Laravel + MySQL + Redis + Reverb, served by its own Caddy, which sits behind the front proxy.
RETAIL_REPO=pardeep24/retail-cloud-erp
RETAIL_SRC="$RUN_DIR/retail/src"

# The project keeps its existing name, "infrastructure" (the folder of its compose file), so its
# volumes (infrastructure_mysql_data and the rest) keep their names on this server and the next.
retail_compose() {
  docker compose -p infrastructure --project-directory "$RETAIL_SRC/infrastructure" \
    --env-file "$RETAIL_SRC/infrastructure/.env.production" \
    -f "$RETAIL_SRC/infrastructure/docker-compose.prod.yml" \
    -f "$GAVITO_HOME/stacks/retail.edge.yml" "$@"
}

retail_deploy() {
  checkout retail "$RETAIL_REPO" "${1:-$RETAIL_REF}"
  link_env retail "$RETAIL_SRC/infrastructure/.env.production"
  # The backend runs migrations on start (RUN_MIGRATIONS on the backend service only).
  retail_compose up -d --build --remove-orphans
  edge_join infrastructure_default
}

retail_start() { retail_compose up -d --no-build; edge_join infrastructure_default; }
retail_stop() { retail_compose stop; }
retail_projects() { echo infrastructure; }
retail_networks() { echo infrastructure_default; }
