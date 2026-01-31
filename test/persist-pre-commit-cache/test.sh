#!/usr/bin/env bash

# Test script for persist-pre-commit-cache feature

set -e

echo "=== Testing persist-pre-commit-cache feature ==="

# Check if volume mount directories exist
echo "Checking volume mount directories..."
[ -d /.persist-precommit-cache ] || {
  echo "Error: /.persist-precommit-cache not found"
  exit 1
}
[ -d /.persist-prek-cache ] || {
  echo "Error: /.persist-prek-cache not found"
  exit 1
}

# Check permissions
echo "Checking directory permissions..."
perms=$(stat -c '%a' /.persist-precommit-cache)
[ "$perms" = "777" ] || {
  echo "Error: /.persist-precommit-cache has wrong permissions: $perms"
  exit 1
}

perms=$(stat -c '%a' /.persist-prek-cache)
[ "$perms" = "777" ] || {
  echo "Error: /.persist-prek-cache has wrong permissions: $perms"
  exit 1
}

# Create a test user cache directory structure
mkdir -p ~/.cache

# Check if symlinks exist (after postCreateCommand runs)
echo "Checking symlinks in user cache..."
if [ -L ~/.cache/pre-commit ]; then
  target=$(readlink ~/.cache/pre-commit)
  [ "$target" = "/.persist-precommit-cache" ] || {
    echo "Error: pre-commit symlink points to wrong target: $target"
    exit 1
  }
  echo "✓ ~/.cache/pre-commit symlink is correct"
fi

if [ -L ~/.cache/prek ]; then
  target=$(readlink ~/.cache/prek)
  [ "$target" = "/.persist-prek-cache" ] || {
    echo "Error: prek symlink points to wrong target: $target"
    exit 1
  }
  echo "✓ ~/.cache/prek symlink is correct"
fi

# Test write access to mounted volumes
echo "Testing write access to mounted volumes..."
touch /.persist-precommit-cache/test-file.txt || {
  echo "Error: Cannot write to /.persist-precommit-cache"
  exit 1
}
touch /.persist-prek-cache/test-file.txt || {
  echo "Error: Cannot write to /.persist-prek-cache"
  exit 1
}
rm /.persist-precommit-cache/test-file.txt /.persist-prek-cache/test-file.txt

echo "=== All tests passed ==="
