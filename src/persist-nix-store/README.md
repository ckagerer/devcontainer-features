# Persist Nix store (persist-nix-store)

Mounts a shared named Docker volume at `/nix/store` so the Nix package store survives container
rebuilds without re-downloading packages.

## Example Usage

```json
"features": {
    "ghcr.io/ckagerer/devcontainer-features/persist-nix-store:1": {}
}
```

Combine with [persist-nix-var](../persist-nix-var/) so Nix also retains its database across
rebuilds and recognises already-present store paths. Add the [chezmoi](../chezmoi/) feature with
`defer_scripts: true` to run Nix installation at post-create time (when the volumes are mounted):

```json
"features": {
    "ghcr.io/ckagerer/devcontainer-features/chezmoi:1": {
        "dotfiles_repo": "your-user/dotfiles",
        "defer_scripts": true
    },
    "ghcr.io/ckagerer/devcontainer-features/persist-nix-store:1": {},
    "ghcr.io/ckagerer/devcontainer-features/persist-nix-var:1": {}
}
```

## How It Works

The volume is mounted at `/nix/store` — not at `/nix`. This is intentional:

- `/nix/store` is content-addressable and safe for concurrent reads. Multiple devcontainers
  can share the same volume simultaneously without conflicts.
- `/nix/var` (the Nix SQLite database, profiles, and GC roots) is handled separately by
  [persist-nix-var](../persist-nix-var/), which uses a per-project volume to avoid SQLite
  write contention between concurrent containers.

Without `persist-nix-var`, Nix loses its database on every rebuild and re-downloads packages
that are already present in the store.

During build, `install.sh` pre-creates `/nix/store` with the remote user's ownership. Docker seeds
an empty named volume from the image layer on first mount, so the directory is writable by the Nix
single-user installer (`--no-daemon`) when it runs at post-create time.

## Volume Name

The volume is named `devcontainer-nix-store` and is shared across all projects by default. Packages
downloaded for one devcontainer are immediately available to others on the same machine without a
separate download.
