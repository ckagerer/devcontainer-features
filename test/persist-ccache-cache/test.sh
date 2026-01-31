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
[ "$perms" = "777" ] || {
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

# Check if environment variables are set (if shell rc files have been sourced)
echo "Checking environment variable configuration..."
if [ -f ~/.bashrc ] || [ -f ~/.zshrc ]; then
  # The init script should have added CCACHE_DIR and CCACHE_MAXSIZE
  # to the shell rc files
  for rc_file in ~/.bashrc ~/.zshrc; do
    if [ -f "$rc_file" ]; then
      if grep -q "CCACHE_DIR" "$rc_file"; then
        echo "✓ CCACHE_DIR found in $rc_file"
      fi
      if grep -q "CCACHE_MAXSIZE" "$rc_file"; then
        echo "✓ CCACHE_MAXSIZE found in $rc_file"
      fi
    fi
  done
fi

echo "=== All tests passed ==="
