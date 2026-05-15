# Persist Nix store (persist-nix-store)

Mounts a named Docker volume at `/nix/store` so the Nix package store survives container rebuilds
without re-downloading packages.

## Example Usage

```json
"features": {
    "ghcr.io/ckagerer/devcontainer-features/persist-nix-store:1": {}
}
```

Combine with the [chezmoi](../chezmoi/) feature and `defer_scripts: true` to skip Nix downloads on
every rebuild:

```json
"features": {
    "ghcr.io/ckagerer/devcontainer-features/chezmoi:1": {
        "dotfiles_repo": "your-user/dotfiles",
        "defer_scripts": true
    },
    "ghcr.io/ckagerer/devcontainer-features/persist-nix-store:1": {}
}
```

## How It Works

The volume is mounted at `/nix/store` — not at `/nix`. This is intentional:

- `/nix/store` is content-addressable and designed for concurrent read access. Multiple devcontainers
  can share the same volume safely, even when open simultaneously.
- `/nix/var` (the Nix SQLite database, profiles, and GC roots) stays inside each container's own
  writable layer. Sharing it would cause database corruption under concurrent writes.

During build, `install.sh` pre-creates `/nix/store` with the remote user's ownership. Docker seeds
an empty named volume from the image layer on first mount, so the directory is writable by the Nix
single-user installer (`--no-daemon`) when it runs at post-create time.

## Volume Name

The volume is named `devcontainer-nix-store` and is shared across all projects by default. Packages
downloaded for one devcontainer are immediately available to others on the same machine without a
separate download.
