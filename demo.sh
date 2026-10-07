#!/usr/bin/env bash
#
# End-to-end demo of the mock charm registry:
#   1. starts the registry as a single background process
#   2. builds a bogus charm archive
#   3. pushes and releases it with stock `charmcraft`
#   4. deploys it with stock `juju`
#
# Everything the registry stores is in memory and vanishes when it exits.
#
# Environment overrides:
#   REGISTRY_HOST     address the Juju controller uses to reach the registry
#   REGISTRY_PORT     port the registry listens on               (default 18080)
#   CHARM_NAME        name to register                      (default mock-demo)
#   CHARM_USER        dev identity to publish as                 (default alice)
#   JUJU_CLOUD        cloud to bootstrap if no controller exists (default localhost)
#   JUJU_CONTROLLER   controller name                       (default mock-registry)
#   SKIP_JUJU=1       stop after the charmcraft phase

set -euo pipefail

REGISTRY_PORT="${REGISTRY_PORT:-18080}"
CHARM_NAME="${CHARM_NAME:-mock-demo}"
CHARM_USER="${CHARM_USER:-alice}"
JUJU_CLOUD="${JUJU_CLOUD:-localhost}"
JUJU_CONTROLLER="${JUJU_CONTROLLER:-mock-registry}"
JUJU_MODEL="demo"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(mktemp -d)"
REGISTRY_PID=""

say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

cleanup() {
  if [[ -n "$REGISTRY_PID" ]] && kill -0 "$REGISTRY_PID" 2>/dev/null; then
    say "Stopping the registry (pid $REGISTRY_PID)"
    kill "$REGISTRY_PID" 2>/dev/null || true
    wait "$REGISTRY_PID" 2>/dev/null || true
  fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

for tool in go charmcraft zip curl; do
  command -v "$tool" >/dev/null || die "$tool is not installed"
done

# The Juju controller runs outside this host's loopback namespace, so it needs a
# routable address for download URLs. Fall back to localhost for charmcraft-only runs.
detect_host() {
  if [[ -n "${REGISTRY_HOST:-}" ]]; then
    echo "$REGISTRY_HOST"
  elif command -v ipconfig >/dev/null 2>&1 && ipconfig getifaddr en0 >/dev/null 2>&1; then
    ipconfig getifaddr en0
  elif command -v ip >/dev/null 2>&1; then
    ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}'
  else
    echo "127.0.0.1"
  fi
}

REGISTRY_HOST="$(detect_host)"
[[ -n "$REGISTRY_HOST" ]] || REGISTRY_HOST="127.0.0.1"
REGISTRY_URL="http://${REGISTRY_HOST}:${REGISTRY_PORT}"

case "$(uname -m)" in
  x86_64|amd64) CHARM_ARCH="amd64" ;;
  arm64|aarch64) CHARM_ARCH="arm64" ;;
  *) CHARM_ARCH="amd64" ;;
esac

# ---------------------------------------------------------------- 1. registry

say "Building the registry binary"
(cd "$REPO_ROOT" && make build >/dev/null)

say "Starting the registry on ${REGISTRY_URL}"
CHARM_REGISTRY_LISTEN=":${REGISTRY_PORT}" \
CHARM_REGISTRY_PUBLIC_API_URL="$REGISTRY_URL" \
CHARM_REGISTRY_PUBLIC_STORAGE_URL="$REGISTRY_URL" \
  "$REPO_ROOT/.bin/charm-registry" &
REGISTRY_PID=$!

for _ in $(seq 1 40); do
  if curl -fsS "${REGISTRY_URL}/" >/dev/null 2>&1; then break; fi
  sleep 0.25
done
curl -fsS "${REGISTRY_URL}/" >/dev/null || die "registry did not come up on ${REGISTRY_URL}"
echo "Registry is serving: $(curl -fsS "${REGISTRY_URL}/")"

# ------------------------------------------------------------- 2. bogus charm

say "Building a bogus charm archive"
CHARM_SRC="${WORK_DIR}/src"
PROJECT_DIR="${WORK_DIR}/project"
mkdir -p "$CHARM_SRC" "$PROJECT_DIR"

# charmcraft 4 refuses to run outside a project, so give it a charmcraft.yaml.
cat >"${PROJECT_DIR}/charmcraft.yaml" <<EOF
name: ${CHARM_NAME}
type: charm
title: Mock Demo Charm
summary: A bogus charm used to exercise the mock registry
description: |
  This charm does nothing useful. It exists to prove that charmcraft can push
  to the mock registry and that juju can pull the same artifact back out.
base: ubuntu@22.04
platforms:
  ${CHARM_ARCH}:
parts:
  charm:
    plugin: dump
    source: .
EOF

# The archive itself only needs metadata.yaml; the registry parses that.
cat >"${CHARM_SRC}/metadata.yaml" <<EOF
name: ${CHARM_NAME}
display-name: Mock Demo Charm
summary: A bogus charm used to exercise the mock registry
description: |
  This charm does nothing useful. It exists to prove that charmcraft can push
  to the mock registry and that juju can pull the same artifact back out.
series:
  - jammy
EOF

cat >"${CHARM_SRC}/manifest.yaml" <<EOF
bases:
  - name: ubuntu
    channel: "22.04"
    architectures:
      - ${CHARM_ARCH}
EOF

cat >"${CHARM_SRC}/config.yaml" <<'EOF'
options: {}
EOF

cat >"${CHARM_SRC}/README.md" <<EOF
# ${CHARM_NAME}

A deliberately bogus charm.
EOF

# `dispatch` is the only executable Juju requires; it just reports active.
cat >"${CHARM_SRC}/dispatch" <<'EOF'
#!/bin/sh
status-set active "bogus charm running from the mock registry"
EOF
chmod +x "${CHARM_SRC}/dispatch"

CHARM_FILE="${WORK_DIR}/${CHARM_NAME}_ubuntu-22.04-${CHARM_ARCH}.charm"
(cd "$CHARM_SRC" && zip -q -r -X "$CHARM_FILE" .)
echo "Built ${CHARM_FILE}"

# -------------------------------------------------------------- 3. charmcraft

export CHARMCRAFT_STORE_API_URL="$REGISTRY_URL"
export CHARMCRAFT_UPLOAD_URL="$REGISTRY_URL"
export CHARMCRAFT_REGISTRY_URL="$REGISTRY_URL"

cd "$PROJECT_DIR"

# charmcraft 4.4+ replaced the old bakery login with an Ubuntu SSO handshake
# (POST /v1/tokens/usso), which this mock does not implement. Handing craft-store
# a token directly via CHARMCRAFT_AUTH skips login entirely and works on 3.x and 4.x.
say "Authenticating as ${CHARM_USER} with a dev token"
CHARMCRAFT_AUTH="$(printf '%s' "dev:${CHARM_USER}:${CHARM_USER}" | base64 | tr -d '\n')"
export CHARMCRAFT_AUTH
charmcraft whoami

say "Registering ${CHARM_NAME}"
charmcraft register "$CHARM_NAME"

say "Uploading the charm"
UPLOAD_OUTPUT="$(charmcraft upload "$CHARM_FILE")"
echo "$UPLOAD_OUTPUT"
REVISION="$(echo "$UPLOAD_OUTPUT" | grep -oE '[Rr]evision [0-9]+' | head -1 | grep -oE '[0-9]+')"
[[ -n "$REVISION" ]] || die "could not determine the uploaded revision"

say "Releasing revision ${REVISION} to latest/stable"
charmcraft release "$CHARM_NAME" --revision="$REVISION" --channel=latest/stable
charmcraft status "$CHARM_NAME"

say "Consumer view (what juju resolves ${CHARM_NAME} to)"
curl -fsS "${REGISTRY_URL}/v2/charms/info/${CHARM_NAME}" | python3 -c '
import json, sys
info = json.load(sys.stdin)
release = info["default-release"]
print("channel: ", release["channel"]["name"])
print("revision:", release["revision"]["revision"])
print("bases:   ", release["revision"]["bases"])
print("download:", release["revision"]["download"]["url"])
'

if [[ "${SKIP_JUJU:-0}" == "1" ]]; then
  say "SKIP_JUJU=1 set; stopping before the juju phase"
  exit 0
fi

command -v juju >/dev/null || die "juju is not installed (re-run with SKIP_JUJU=1)"

# -------------------------------------------------------------------- 4. juju

if juju show-controller "$JUJU_CONTROLLER" >/dev/null 2>&1; then
  say "Reusing the existing controller ${JUJU_CONTROLLER}"
  juju switch "$JUJU_CONTROLLER" >/dev/null
else
  say "Bootstrapping controller ${JUJU_CONTROLLER} on ${JUJU_CLOUD}"
  juju bootstrap "$JUJU_CLOUD" "$JUJU_CONTROLLER" --config charmhub-url="$REGISTRY_URL"
fi

say "Creating model ${JUJU_MODEL} pointed at the mock registry"
juju destroy-model "$JUJU_MODEL" --no-prompt --force 2>/dev/null || true
juju add-model "$JUJU_MODEL" --config charmhub-url="$REGISTRY_URL"
juju model-config charmhub-url

say "Deploying ${CHARM_NAME} from the mock registry"
juju deploy "$CHARM_NAME" --channel=latest/stable --base="ubuntu@22.04"

say "Waiting for the unit to settle"
if ! juju wait-for application "$CHARM_NAME" --timeout=10m; then
  echo "wait-for did not succeed; dumping current status"
fi
juju status

say "Done. Tear down with: juju destroy-model ${JUJU_MODEL} --no-prompt --force"
