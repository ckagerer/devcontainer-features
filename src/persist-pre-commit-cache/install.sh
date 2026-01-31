#!/usr/bin/env sh

# Initialize pre-commit cache volume directories
# This script runs as root during container build

if [ "${KEEP_GOING:-false}" = "true" ]; then
  set +e
else
  set -e
fi
set -x

# Create cache directories with permissions for all users
mkdir -p /.persist-precommit-cache /.persist-prek-cache
chmod 777 /.persist-precommit-cache /.persist-prek-cache

# Generate the postCreateCommand script that runs in user context
INIT_SCRIPT_PATH="/usr/local/share/persist-precommit-init.sh"

tee "$INIT_SCRIPT_PATH" >/dev/null <<'EOF'
#!/usr/bin/env bash

# Initialize pre-commit cache symlinks in user home directory
# This script runs in user context (postCreateCommand)

set -e
set -x

# Handle existing ~/.cache/pre-commit directory
if [ -d ~/.cache/pre-commit ] && [ ! -L ~/.cache/pre-commit ]; then
  echo "Backing up existing ~/.cache/pre-commit to ~/.cache/pre-commit.bak"
  mv ~/.cache/pre-commit ~/.cache/pre-commit.bak
fi

# Create symlink for pre-commit cache if it doesn't already exist
if [ ! -L ~/.cache/pre-commit ]; then
  mkdir -p ~/.cache
  ln -s /.persist-precommit-cache ~/.cache/pre-commit
  echo "Created symlink: ~/.cache/pre-commit -> /.persist-precommit-cache"
fi

# Handle existing ~/.cache/prek directory
if [ -d ~/.cache/prek ] && [ ! -L ~/.cache/prek ]; then
  echo "Backing up existing ~/.cache/prek to ~/.cache/prek.bak"
  mv ~/.cache/prek ~/.cache/prek.bak
fi

# Create symlink for prek cache if it doesn't already exist
if [ ! -L ~/.cache/prek ]; then
  mkdir -p ~/.cache
  ln -s /.persist-prek-cache ~/.cache/prek
  echo "Created symlink: ~/.cache/prek -> /.persist-prek-cache"
fi

echo "Pre-commit cache initialization complete"
EOF

chmod 755 "$INIT_SCRIPT_PATH"

echo "Pre-commit cache feature installation complete"
