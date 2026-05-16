#!/usr/bin/env bash
# (C) Copyright 2025 Christian Kagerer
# Purpose: Prepare /nix with correct ownership for the named volume mount.
#
# The volume is mounted at /nix/store (not /nix) so each container keeps its
# own /nix/var (Nix DB, profiles, gcroots) — avoiding SQLite corruption when
# multiple containers share the store simultaneously.
#
# Docker seeds an empty named volume from the image layer on first mount.
# Pre-creating /nix/store with the remote user's ownership here ensures the
# volume initialises with the right permissions for the Nix single-user
# installer (--no-daemon) to write to the store at post-create time.

set -o errexit -o nounset -o pipefail

mkdir -p /nix/store
chown "${_REMOTE_USER}:$(id -gn "${_REMOTE_USER}")" /nix /nix/store
chmod 755 /nix /nix/store

echo "Done"
