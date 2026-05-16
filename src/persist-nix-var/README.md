# Persist Nix var (persist-nix-var)

Mounts a per-project named Docker volume at `/nix/var` so the Nix SQLite database,
user profiles, and GC roots survive container rebuilds.

Without this feature, Nix loses its database on every rebuild and re-downloads packages
that are already present in `/nix/store` — even when used together with
[persist-nix-store](../persist-nix-store/).

## Example Usage

```json
"features": {
    "ghcr.io/ckagerer/devcontainer-features/persist-nix-store:1": {},
    "ghcr.io/ckagerer/devcontainer-features/persist-nix-var:1": {}
}
```

Combine with the [chezmoi](../chezmoi/) feature and `defer_scripts: true` to fully skip
Nix downloads on rebuilds:

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

The volume is mounted at `/nix/var` — not at `/nix`. This is intentional:

- `/nix/var` contains the Nix SQLite database (`db/`), per-user profiles (`profiles/`),
  and GC roots (`gcroots/`). Persisting it ensures Nix recognises store paths that are
  already present in `/nix/store` and skips redundant downloads.
- The volume is **per-project** (named with `${localWorkspaceFolderBasename}` and
  `${devcontainerId}`), so concurrent devcontainers each have their own isolated database.
  This avoids SQLite write contention and profile conflicts that would occur with a shared
  `/nix/var`.

## Volume Name

The volume is named `devcontainer-<project>-persist-nix-var-<id>` and is scoped to each
devcontainer. Combined with the shared `devcontainer-nix-store` volume from
[persist-nix-store](../persist-nix-store/), packages are downloaded once and registered
once per project — surviving all subsequent rebuilds.
