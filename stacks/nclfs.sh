# shellcheck shell=bash
# The NCLFS school app demo, nclfns.gavitotechnologies.com (pardeep24/nclfns-school-app): a copy
# for showing the app, with demo data only. The real school runs on its own server in Canada.
# Its own deploy-on-server.sh builds and releases the copy; this only points it at folders here.
NCLFS_REPO=pardeep24/nclfns-school-app
NCLFS_SRC="$RUN_DIR/nclfs/src"
NCLFS_DEMO_DIR="$RUN_DIR/nclfs/nclfs-demo"

# `./gavito deploy nclfs` releases versions.env's ref; `./gavito deploy nclfs <ref>` another one.
nclfs_deploy() {
  checkout nclfs "$NCLFS_REPO" "${1:-$NCLFS_REF}"
  # Run from a copy: the release checks the code out again, which replaces the script in src.
  local script="$RUN_DIR/nclfs/deploy-on-server.sh"
  cp "$NCLFS_SRC/infra/nclfs/deploy-on-server.sh" "$script"
  chmod +x "$script"
  mkdir -p "$NCLFS_DEMO_DIR"
  link_env nclfs-demo "$NCLFS_DEMO_DIR/.env"
  NCLFS_SRC="$NCLFS_SRC" NCLFS_DEMO_APP="$NCLFS_DEMO_DIR" \
    "$script" demo "$(git -C "$NCLFS_SRC" rev-parse HEAD)"
  edge_join nclfs-demo_default
}

# Loads the NCLFS demo people and data, and the old nclfns.com site's public content (once; run
# again, it adds only what is new). Not part of deploy, so a redeploy keeps what people changed.
nclfs_demo_data() {
  NCLFS_SRC="$NCLFS_SRC" NCLFS_DEMO_APP="$NCLFS_DEMO_DIR" "$RUN_DIR/nclfs/deploy-on-server.sh" demo-data
}

nclfs_compose() { docker compose --project-directory "$NCLFS_DEMO_DIR" "$@"; }
nclfs_start() {
  (cd "$NCLFS_DEMO_DIR" && API_TAG=$(cat .release-current) docker compose up -d --no-build)
  edge_join nclfs-demo_default
}
nclfs_stop() { (cd "$NCLFS_DEMO_DIR" && API_TAG=unused docker compose stop); }
nclfs_projects() { printf '%s\n' nclfs-demo; }
nclfs_networks() { printf '%s\n' nclfs-demo_default; }
