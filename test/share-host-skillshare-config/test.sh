#!/usr/bin/env sh
# Test script for share-host-skillshare-config feature
#
# Tests can be run locally with:
#
#    devcontainer features test                    \
#               --features share-host-skillshare-config \
#               --skip-scenarios                   \
#               --base-image ubuntu:jammy           \
#               /path/to/this/repo

set -e

STAGE="/.host-skillshare-config"
DEST="$HOME/.config/skillshare"
INIT_SCRIPT="/usr/local/share/share-host-skillshare-config-init.sh"

echo "Testing share-host-skillshare-config feature"

# Verify init script was emitted by install.sh
if [ ! -x "$INIT_SCRIPT" ]; then
  echo "FAIL: $INIT_SCRIPT missing or not executable"
  exit 1
fi
echo "PASS: init script exists and is executable"

# Reset DEST — postCreateCommand may have already run and created symlinks
rm -rf "$DEST"
mkdir -p "$(dirname "$DEST")"

# Set up fake staging content (simulates host ~/.config/skillshare)
mkdir -p "$STAGE/skills" "$STAGE/extras" "$STAGE/agents"
echo "version: 1" >"$STAGE/config.yaml"

# Run init with mount check bypassed (no real bind mount in test)
SKIP_MOUNT_CHECK=true SKIP_UID_CHECK=true "$INIT_SCRIPT"

# --- DEST must be a symlink pointing to STAGE ---
target="$(readlink "$DEST" 2>/dev/null || true)"
if [ "$target" = "$STAGE" ]; then
  echo "PASS: $DEST -> $STAGE"
else
  echo "FAIL: expected $DEST symlink to $STAGE, got: $target"
  exit 1
fi

# --- staged content accessible through DEST ---
if [ -d "$DEST/skills" ] && [ -d "$DEST/extras" ] && [ -d "$DEST/agents" ]; then
  echo "PASS: skills, extras, agents accessible via symlink"
else
  echo "FAIL: staged subdirs not accessible through $DEST"
  exit 1
fi

# --- pre-existing container content backed up ---
# Re-run with pre-existing real dir to verify backup
rm "$DEST"
mkdir -p "$DEST"
echo "container-owned" >"$DEST/local.md"
SKIP_MOUNT_CHECK=true SKIP_UID_CHECK=true "$INIT_SCRIPT"
backup=$(find "$(dirname "$DEST")" -maxdepth 1 -name "skillshare.pre-share.*" | head -1)
if [ -z "$backup" ]; then
  echo "FAIL: pre-existing skillshare/ not backed up"
  exit 1
fi
echo "PASS: pre-existing skillshare/ backed up to $backup"

echo "All tests passed"
