#!/usr/bin/env sh
# Test script for share-host-claude-config feature
#
# Tests can be run locally with:
#
#    devcontainer features test         \
#               --features share-host-claude-config \
#               --skip-scenarios        \
#               --base-image ubuntu:jammy \
#               /path/to/this/repo

set -e

STAGE="/.host-claude"
DEST="$HOME/.claude"
INIT_SCRIPT="/usr/local/share/share-host-claude-config-init.sh"

echo "Testing share-host-claude-config feature"

# Verify init script was emitted by install.sh
if [ ! -x "$INIT_SCRIPT" ]; then
  echo "FAIL: $INIT_SCRIPT missing or not executable"
  exit 1
fi
echo "PASS: init script exists and is executable"

# Reset DEST — postCreateCommand may have already run and created symlinks
rm -rf "$DEST"
mkdir -p "$DEST"

# Set up fake staging content (simulates host ~/.claude)
mkdir -p "$STAGE/agents" "$STAGE/commands" "$STAGE/skills" \
  "$STAGE/hooks" "$STAGE/rules" "$STAGE/plugins"
echo "# test CLAUDE.md" >"$STAGE/CLAUDE.md"

# Pre-existing container content — must be backed up, not overwritten
mkdir -p "$DEST/skills"
echo "container-owned" >"$DEST/skills/local.md"

# Run init with mount check bypassed (no real bind mount in test)
SKIP_MOUNT_CHECK=true SKIP_UID_CHECK=true "$INIT_SCRIPT"

# --- default-linked subpaths ---
for name in CLAUDE.md agents commands skills hooks rules plugins; do
  target="$(readlink "$DEST/$name" 2>/dev/null || true)"
  expected="$STAGE/$name"
  if [ "$target" = "$expected" ]; then
    echo "PASS: $name -> $target"
  else
    echo "FAIL: $name expected symlink to $expected, got: $target"
    exit 1
  fi
done

# --- opt-in subpaths must NOT be linked by default ---
for name in sessions projects tasks history.jsonl claude.json settings.json; do
  if [ -L "$DEST/$name" ]; then
    echo "FAIL: $name should not be symlinked by default"
    exit 1
  fi
  echo "PASS: $name not linked (opt-in default)"
done

# --- pre-existing container content backed up ---
backup=$(find "$DEST" -maxdepth 1 -name "skills.pre-share.*" | head -1)
if [ -z "$backup" ]; then
  echo "FAIL: pre-existing skills/ not backed up"
  exit 1
fi
echo "PASS: pre-existing skills/ backed up to $backup"

# --- host-missing subpath skipped gracefully ---
# sessions/ not in staging — init must not fail, just skip
echo "PASS: missing host subpath handled gracefully (no exit 1)"

echo "All tests passed"
