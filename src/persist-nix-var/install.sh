#!/usr/bin/env bash
# (C) Copyright 2026 Christian Kagerer
# Purpose: Pre-create /nix/var with correct ownership so Docker seeds the
# per-project named volume from the image layer on first mount.
#
# The volume is mounted at /nix/var (not /nix) so each project keeps its own
# Nix SQLite database, profiles, and GC roots — avoiding lock contention when
# multiple devcontainers share the same /nix/store volume simultaneously.

set -o errexit -o nounset -o pipefail

mkdir -p /nix/var
# chown /nix itself handles the standalone case (persist-nix-store may not be present)
chown "${_REMOTE_USER}:$(id -gn "${_REMOTE_USER}")" /nix /nix/var
chmod 755 /nix /nix/var

echo "Done"
