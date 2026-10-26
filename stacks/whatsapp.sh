# shellcheck shell=bash
# Gavito WhatsApp CRM (pardeep24/gavito-whatsapp-crm). Already supports running behind another
# proxy: env/whatsapp.env sets COMPOSE_FILE to its behind-proxy files and PROXY_NETWORK to the
# front proxy's network, where its Caddy answers as gavito-caddy:80.
WHATSAPP_REPO=pardeep24/gavito-whatsapp-crm
WHATSAPP_SRC="$RUN_DIR/whatsapp/src"

whatsapp_deploy() {
  checkout whatsapp "$WHATSAPP_REPO" "${1:-$WHATSAPP_REF}"
  link_env whatsapp "$WHATSAPP_SRC/deploy/.env"
  # Backs up the database first, like the app's own update.sh; up.sh runs migrations before the app starts.
  if docker compose --project-directory "$WHATSAPP_SRC/deploy" ps --status running postgres 2>/dev/null | grep -q postgres; then
    "$WHATSAPP_SRC/deploy/backup.sh"
  fi
  "$WHATSAPP_SRC/deploy/up.sh"
}

whatsapp_compose() {
  (cd "$WHATSAPP_SRC/deploy" &&
    if grep -Eq '^META_APP_SECRET=.{16,}' .env; then export COMPOSE_PROFILES=whatsapp; fi &&
    docker compose "$@")
}
whatsapp_start() { whatsapp_compose up -d --no-build; }
whatsapp_stop() { whatsapp_compose stop; }
whatsapp_projects() { echo gavito; }
whatsapp_networks() { :; }  # it joins gavito-edge itself
