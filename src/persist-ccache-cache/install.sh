#!/usr/bin/env sh
# (C) Copyright 2026 Christian Kagerer
# Purpose: Initialize ccache volume directory and configuration
# This script runs as root during container build

if [ "${KEEP_GOING:-false}" = "true" ]; then
  set +e
else
  set -e
fi
set -x

# Create cache directory with permissions for all users
mkdir -p /.persist-ccache
chmod 1777 /.persist-ccache

# Generate the postCreateCommand script that runs in user context
INIT_SCRIPT_PATH="/usr/local/share/persist-ccache-init.sh"

tee "$INIT_SCRIPT_PATH" >/dev/null <<'EOF'
#!/usr/bin/env sh

# Initialize ccache symlinks and environment configuration
# This script runs in user context (postCreateCommand)

set -e
set -x

# CCACHE_MAXSIZE is set below by the installer (sed replacement)
CCACHE_MAXSIZE="__CCACHE_MAXSIZE_PLACEHOLDER__"

# Check if a path is a mount point
is_mount_point() {
  if command -v mountpoint >/dev/null 2>&1; then
    mountpoint -q "$1"
  else
    # Fallback for systems without mountpoint command
    mount | grep -q " on $(readlink -f "$1") "
  fi
  return $?
}

# Handle existing ~/.cache/ccache directory
if [ -d ~/.cache/ccache ] && [ ! -L ~/.cache/ccache ]; then
  # Check if it's already a mount point (e.g., from another devcontainer feature)
  if is_mount_point ~/.cache/ccache 2>/dev/null; then
    echo "Note: ~/.cache/ccache is already mounted by another feature, skipping backup"
  else
    echo "Backing up existing ~/.cache/ccache to ~/.cache/ccache.bak"
    mv ~/.cache/ccache ~/.cache/ccache.bak
  fi
fi

# Create symlink for ccache cache if it doesn't already exist
if [ ! -L ~/.cache/ccache ] && [ ! -d ~/.cache/ccache ]; then
  mkdir -p ~/.cache
  ln -s /.persist-ccache ~/.cache/ccache
  echo "Created symlink: ~/.cache/ccache -> /.persist-ccache"
fi

# Initialize ccache with max size if it hasn't been configured yet
if [ ! -f ~/.cache/ccache/ccache.conf ]; then
  # Create ccache configuration directory
  mkdir -p ~/.cache/ccache

  # Set the maximum cache size
  ccache -M "$CCACHE_MAXSIZE" 2>/dev/null || {
    echo "ccache not yet installed, configuration will be set on first use"
  }
fi

# Set environment variable for ccache directory
export CCACHE_DIR=~/.cache/ccache
export CCACHE_MAXSIZE="${CCACHE_MAXSIZE}"

echo "ccache persistence initialization complete"
echo "  Cache directory: ~/.cache/ccache (symlink to /.persist-ccache)"
echo "  Max cache size: $CCACHE_MAXSIZE"
EOF

# Inject the configured CCACHE_MAXSIZE value into the generated script
sed -i "s|__CCACHE_MAXSIZE_PLACEHOLDER__|${CCACHE_MAXSIZE:-5G}|g" "$INIT_SCRIPT_PATH"

chmod 755 "$INIT_SCRIPT_PATH"

# Write env vars to system-wide shell config so they work regardless of how the
# user's shell is managed (e.g. Home Manager manages ~/.zshrc as a read-only Nix store path)
if [ -f /etc/bash.bashrc ] && ! grep -q "# persist-ccache-cache" /etc/bash.bashrc; then
  {
    printf '\n# persist-ccache-cache\n'
    # shellcheck disable=SC2016
    printf 'export CCACHE_DIR="${HOME}/.cache/ccache"\n'
    printf 'export CCACHE_MAXSIZE='"'"'%s'"'"'\n' "${CCACHE_MAXSIZE:-5G}"
  } >>/etc/bash.bashrc
fi

if [ -d /etc/zsh ] && ! grep -q "# persist-ccache-cache" /etc/zsh/zshenv 2>/dev/null; then
  {
    printf '\n# persist-ccache-cache\n'
    # shellcheck disable=SC2016
    printf 'export CCACHE_DIR="${HOME}/.cache/ccache"\n'
    printf 'export CCACHE_MAXSIZE='"'"'%s'"'"'\n' "${CCACHE_MAXSIZE:-5G}"
  } >>/etc/zsh/zshenv
fi

echo "ccache persistence feature installation complete"
