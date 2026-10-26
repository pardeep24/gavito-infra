# shellcheck shell=bash
# Gavito Edu, edu.gavitotechnologies.com and staging.edu (pardeep24/school-saas).
# Its own deploy-on-server.sh builds and releases each copy; this only points it at folders here.
SCHOOL_REPO=pardeep24/school-saas
SCHOOL_SRC="$RUN_DIR/school/src"

# Staging first, then production with exactly the version staging runs (as the Edu runbook says).
# `./gavito deploy school` does both; `./gavito deploy school <ref>` sends <ref> to staging first.
school_deploy() {
  checkout school "$SCHOOL_REPO" "${1:-$SCHOOL_REF}"
  # The release script always comes from main, whatever version is released: older versions of it
  # predate SCHOOL_SRC and SCHOOL_APP_ROOT and would release to /opt/school-saas-* instead.
  local script="$RUN_DIR/school/deploy-on-server.sh" target
  git -C "$SCHOOL_SRC" show origin/main:infra/staging/deploy-on-server.sh > "$script"
  grep -q SCHOOL_APP_ROOT "$script" || die "school-saas main has no SCHOOL_APP_ROOT support"
  chmod +x "$script"
  for target in staging production; do
    mkdir -p "$RUN_DIR/school/school-saas-$target"
    link_env "school-$target" "$RUN_DIR/school/school-saas-$target/.env"
    # SCHOOL_SRC and SCHOOL_APP_ROOT come from pardeep24/school-saas#80, which makes these paths
    # settable (they are /opt/school-saas-src and /opt/school-saas-<target> today).
    if [ "$target" = staging ]; then
      SCHOOL_SRC="$SCHOOL_SRC" SCHOOL_APP_ROOT="$RUN_DIR/school" \
        "$script" staging "$(git -C "$SCHOOL_SRC" rev-parse HEAD)"
    else
      SCHOOL_SRC="$SCHOOL_SRC" SCHOOL_APP_ROOT="$RUN_DIR/school" \
        "$script" production
    fi
    edge_join "school-saas-${target}_default"
  done
}

school_compose() { docker compose --project-directory "$RUN_DIR/school/school-saas-$1" "${@:2}"; }
school_start() {
  local t
  for t in staging production; do
    (cd "$RUN_DIR/school/school-saas-$t" && API_TAG=$(docker inspect "school-saas-$t-api-1" --format '{{.Config.Image}}' 2>/dev/null | cut -d: -f2) docker compose up -d --no-build)
    edge_join "school-saas-${t}_default"
  done
}
school_stop() {
  local t
  for t in staging production; do
    (cd "$RUN_DIR/school/school-saas-$t" && API_TAG=unused docker compose stop)
  done
}
school_projects() { printf '%s\n' school-saas-staging school-saas-production; }
school_networks() { printf '%s\n' school-saas-staging_default school-saas-production_default; }
