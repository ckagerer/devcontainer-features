#!/usr/bin/env bash
# Tests that the init script symlinks correctly under a non-root user.

set -e

STAGE="/.host-claude"
DEST="$HOME/.claude"
INIT_SCRIPT="/usr/local/share/share-host-claude-config-init.sh"

echo "Testing share-host-claude-config as non-root user: $(id -un)"

if [ ! -x "$INIT_SCRIPT" ]; then
  echo "FAIL: $INIT_SCRIPT missing or not executable"
  exit 1
fi
echo "PASS: init script exists and is executable"

rm -rf "$DEST"
mkdir -p "$STAGE/agents" "$STAGE/skills"
echo "# test CLAUDE.md" >"$STAGE/CLAUDE.md"

SKIP_MOUNT_CHECK=true SKIP_UID_CHECK=true "$INIT_SCRIPT"

for name in CLAUDE.md agents skills; do
  target="$(readlink "$DEST/$name" 2>/dev/null || true)"
  expected="$STAGE/$name"
  if [ "$target" = "$expected" ]; then
    echo "PASS: $name -> $target"
  else
    echo "FAIL: $name expected symlink to $expected, got: $target"
    exit 1
  fi
done

echo "All tests passed"
