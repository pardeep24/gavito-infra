# shellcheck shell=bash
# CRM Cafe, food.gavitotechnologies.com and each cafe's <slug>.food subdomain (pardeep24/CRM-Cafe).
# PostgreSQL, Redis, API, Celery worker and Next.js, behind its own Caddy (crm-cafe-web:80).
CAFE_REPO=pardeep24/CRM-Cafe
CAFE_SRC="$RUN_DIR/cafe/src"

cafe_compose() {
  docker compose --project-directory "$CAFE_SRC/deploy" -f "$CAFE_SRC/deploy/docker-compose.yml" "$@"
}

cafe_deploy() {
  checkout cafe "$CAFE_REPO" "${1:-$CAFE_REF}"
  link_env cafe "$CAFE_SRC/deploy/.env"
  # The migrate service applies Alembic migrations before the API and worker start.
  cafe_compose up -d --build --remove-orphans
  edge_join crm-cafe_default
}

cafe_start() { cafe_compose up -d --no-build; edge_join crm-cafe_default; }
cafe_stop() { cafe_compose stop; }
cafe_projects() { echo crm-cafe; }
cafe_networks() { echo crm-cafe_default; }
