#!/bin/sh

# This test file will be executed against an auto-generated devcontainer.json that
# includes the 'persist-claude-mem' Feature with no options.
#
# For more information, see: https://github.com/devcontainers/cli/blob/main/docs/features/test.md
#
# Eg:
# {
#    "image": "ubuntu:jammy",
#    "features": {
#      "persist-claude-mem": {}
#    },
#    "remoteUser": "testuser"
# }
#
# Thus, the value of all options will fall back to the default value in the
# Feature's 'devcontainer-feature.json'.
#
# These scripts are run as 'testuser' by default.
#
# This test can be run with the following command:
#
#    devcontainer features test    \
#               --features persist-claude-mem   \
#               --remote-user testuser \
#               --skip-scenarios   \
#               --base-image ubuntu:jammy \
#               /path/to/this/repo

set -e

# Direct tests without test library for Alpine compatibility

echo "Testing persist-claude-mem feature..."

# Check if init script exists and is executable
if [ -f /usr/local/share/persist-claude-mem-init.sh ] && [ -x /usr/local/share/persist-claude-mem-init.sh ]; then
  echo "✓ init script exists and is executable"
else
  echo "✗ Failure: init script not found or not executable"
  exit 1
fi

# Reset any prior symlink for clean test
rm -rf "${HOME}/.claude-mem"

# Simulate Docker volume mount. Safe: install.sh pre-creates this dir with chmod 777,
# so in scenarios mode (testuser) it already exists; in --skip-scenarios mode we run as root.
mkdir -p /.persist-claude-mem

# Test 1: Fresh run - init script creates symlink
/usr/local/share/persist-claude-mem-init.sh

if [ -L "${HOME}/.claude-mem" ]; then
  echo "✓ .claude-mem is a symlink"
else
  echo "✗ Failure: .claude-mem is not a symlink"
  exit 1
fi

# Verify symlink points to the correct target
if [ "$(readlink "${HOME}/.claude-mem")" = "/.persist-claude-mem" ]; then
  echo "✓ .claude-mem symlink points to /.persist-claude-mem"
else
  echo "✗ Failure: .claude-mem symlink does not point to /.persist-claude-mem"
  exit 1
fi

# Test 2: Staged content accessible through symlink
test_file="${HOME}/.claude-mem/test-file.txt"
echo "test content" >"/.persist-claude-mem/test-file.txt"

if [ -f "${test_file}" ]; then
  echo "✓ file created in /.persist-claude-mem is accessible via .claude-mem symlink"
else
  echo "✗ Failure: file in /.persist-claude-mem not accessible via .claude-mem"
  exit 1
fi

# Verify content matches
if [ "$(cat "${test_file}")" = "test content" ]; then
  echo "✓ symlink content is correct"
else
  echo "✗ Failure: symlink content does not match"
  exit 1
fi

# Test 3: Idempotent - running init script again leaves symlink intact
/usr/local/share/persist-claude-mem-init.sh

if [ -L "${HOME}/.claude-mem" ] && [ "$(readlink "${HOME}/.claude-mem")" = "/.persist-claude-mem" ]; then
  echo "✓ init script is idempotent - symlink remains intact"
else
  echo "✗ Failure: symlink was modified by second run"
  exit 1
fi

# Test 4: Dangling symlink is replaced
rm -f "${HOME}/.claude-mem"
ln -s /nonexistent-target "${HOME}/.claude-mem"

/usr/local/share/persist-claude-mem-init.sh

if [ -L "${HOME}/.claude-mem" ] && [ "$(readlink "${HOME}/.claude-mem")" = "/.persist-claude-mem" ]; then
  echo "✓ dangling symlink was replaced with correct symlink"
else
  echo "✗ Failure: dangling symlink was not replaced"
  exit 1
fi

# Test 5: Pre-existing real directory is backed up
rm -f "${HOME}/.claude-mem"
# Clean up any leftover backup dirs from prior runs to make find deterministic
find "${HOME}" -maxdepth 1 -name ".claude-mem.pre-persist.*" -type d -exec rm -rf {} + 2>/dev/null || true
mkdir -p "${HOME}/.claude-mem"
echo "pre-existing content" >"${HOME}/.claude-mem/existing-file.txt"

/usr/local/share/persist-claude-mem-init.sh

# Check if backup directory exists with .pre-persist.* pattern
backup_dir=$(find "${HOME}" -maxdepth 1 -name ".claude-mem.pre-persist.*" -type d | head -1)
if [ -n "${backup_dir}" ] && [ -f "${backup_dir}/existing-file.txt" ]; then
  echo "✓ pre-existing .claude-mem directory was backed up"
else
  echo "✗ Failure: pre-existing directory was not backed up"
  exit 1
fi

# Verify symlink was created after backup
if [ -L "${HOME}/.claude-mem" ] && [ "$(readlink "${HOME}/.claude-mem")" = "/.persist-claude-mem" ]; then
  echo "✓ symlink was created after backing up pre-existing directory"
else
  echo "✗ Failure: symlink was not created after backup"
  exit 1
fi

echo "✓ All tests passed"
