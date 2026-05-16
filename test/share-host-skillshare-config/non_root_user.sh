#!/usr/bin/env bash
# Tests that the init script symlinks correctly under a non-root user.

set -e

STAGE="/.host-skillshare-config"
DEST="$HOME/.config/skillshare"
INIT_SCRIPT="/usr/local/share/share-host-skillshare-config-init.sh"

echo "Testing share-host-skillshare-config as non-root user: $(id -un)"

if [ ! -x "$INIT_SCRIPT" ]; then
  echo "FAIL: $INIT_SCRIPT missing or not executable"
  exit 1
fi
echo "PASS: init script exists and is executable"

rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"
mkdir -p "$STAGE/skills" "$STAGE/extras" "$STAGE/agents"
echo "version: 1" >"$STAGE/config.yaml"

SKIP_MOUNT_CHECK=true SKIP_UID_CHECK=true "$INIT_SCRIPT"

target="$(readlink "$DEST" 2>/dev/null || true)"
if [ "$target" = "$STAGE" ]; then
  echo "PASS: $DEST -> $STAGE"
else
  echo "FAIL: expected $DEST symlink to $STAGE, got: $target"
  exit 1
fi

echo "All tests passed"
