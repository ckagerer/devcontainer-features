#!/bin/sh

# Test script for persist-ccache feature

set -e

echo "=== Testing persist-ccache feature ==="

# Check if volume mount directory exists
echo "Checking volume mount directory..."
[ -d /.persist-ccache ] || {
  echo "Error: /.persist-ccache not found"
  exit 1
}

# Check permissions
echo "Checking directory permissions..."
perms=$(stat -c '%a' /.persist-ccache)
[ "$perms" = "1777" ] || {
  echo "Error: /.persist-ccache has wrong permissions: $perms"
  exit 1
}

# Create a test user cache directory structure
mkdir -p ~/.cache

# Check if symlinks exist (after postCreateCommand runs)
echo "Checking symlinks in user cache..."
if [ -L ~/.cache/ccache ]; then
  target=$(readlink ~/.cache/ccache)
  [ "$target" = "/.persist-ccache" ] || {
    echo "Error: ccache symlink points to wrong target: $target"
    exit 1
  }
  echo "✓ ~/.cache/ccache symlink is correct"
fi

# Test write access to mounted volume
echo "Testing write access to mounted volume..."
touch /.persist-ccache/test-file.txt || {
  echo "Error: Cannot write to /.persist-ccache"
  exit 1
}
rm /.persist-ccache/test-file.txt

# Check env vars in system-wide shell config (written by install.sh as root)
echo "Checking environment variable configuration..."
for rc_file in /etc/bash.bashrc /etc/zsh/zshenv; do
  if [ -f "$rc_file" ]; then
    grep -q "CCACHE_DIR" "$rc_file" && echo "✓ CCACHE_DIR found in $rc_file" || echo "✗ CCACHE_DIR missing from $rc_file"
    grep -q "CCACHE_MAXSIZE" "$rc_file" && echo "✓ CCACHE_MAXSIZE found in $rc_file" || echo "✗ CCACHE_MAXSIZE missing from $rc_file"
  fi
done

echo "=== All tests passed ==="
