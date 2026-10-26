# shellcheck shell=bash
# Shared helpers for ./gavito and the stack files. Sourced, never run on its own.

# The folder this repository is cloned to on the server (normally /opt/gavito).
GAVITO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Run from here: docker compose fails with "stat .: permission denied" when started from a folder
# the deploy user can't read, such as /root after `sudo -u deploy`.
CALLER_DIR="$PWD"
cd "$GAVITO_HOME"
RUN_DIR="$GAVITO_HOME/run"
ENV_DIR="$GAVITO_HOME/env"
BACKUP_DIR="$GAVITO_HOME/backups"

# The front proxy's container and the Docker network every app's entry container joins.
EDGE_CONTAINER=gavito-edge
EDGE_NETWORK=gavito-edge

# Every app, in the order they start. Cafe joins once it runs in Docker.
ALL_STACKS=(website retail school whatsapp)

log() { printf '==> %s\n' "$*"; }
warn() { printf '!! %s\n' "$*" >&2; }
die() { warn "$*"; exit 1; }

# Server-wide settings: the GitHub token used to fetch the app repositories.
load_settings() {
  # shellcheck source=/dev/null
  . "$GAVITO_HOME/versions.env"
  if [ -f "$ENV_DIR/gavito.env" ]; then
    # shellcheck source=/dev/null
    . "$ENV_DIR/gavito.env"
  fi
}

# Clones or updates an app repository in run/<app>/src and checks out a ref (branch, tag or
# commit). Uses GITHUB_TOKEN from env/gavito.env: one fine-grained token with read access to the
# app repositories, instead of one deploy key per repository.
checkout() {
  local app="$1" repo="$2" ref="$3" src="$RUN_DIR/$1/src"
  local auth=()
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    auth=(-c "http.https://github.com/.extraheader=Authorization: Basic $(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 -w0)")
  fi
  mkdir -p "$RUN_DIR/$app"
  if [ ! -d "$src/.git" ]; then
    log "$app: cloning $repo"
    git "${auth[@]}" clone --quiet "https://github.com/$repo.git" "$src"
  fi
  # Kept in the checkout too, for apps whose own deploy script fetches again (school).
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    git -C "$src" config --local "${auth[1]%%=*}" "${auth[1]#*=}"
  fi
  git -C "$src" fetch --quiet --tags origin
  if git -C "$src" rev-parse --quiet --verify "origin/$ref^{commit}" >/dev/null; then
    git -C "$src" checkout --quiet --force "origin/$ref"
  else
    git -C "$src" checkout --quiet --force "$ref"
  fi
  log "$app: at $(git -C "$src" rev-parse --short=12 HEAD) ($(git -C "$src" log -1 --format=%s))"
}

# Links an app's settings file from env/ to the path the app expects, so all settings live in one
# folder (env/) that a server move copies as a whole.
link_env() {
  local name="$1" target="$2"
  [ -f "$ENV_DIR/$name.env" ] || die "env/$name.env is missing. Start from env/$name.env.example."
  chmod 600 "$ENV_DIR/$name.env"
  ln -sfn "$ENV_DIR/$name.env" "$target"
}

# Joins the front proxy to an app's network so it can reach that app's entry container. Joining
# is lost when the proxy container is recreated, so `./gavito up` runs it again every time.
edge_join() {
  local network="$1"
  docker network inspect "$network" >/dev/null 2>&1 || { warn "network $network does not exist yet"; return 0; }
  # `docker container inspect`, not `docker inspect`: the edge network has the same name.
  docker container inspect "$EDGE_CONTAINER" >/dev/null 2>&1 || return 0
  if ! docker container inspect "$EDGE_CONTAINER" --format '{{json .NetworkSettings.Networks}}' | grep -q "\"$network\""; then
    docker network connect "$network" "$EDGE_CONTAINER"
  fi
}
