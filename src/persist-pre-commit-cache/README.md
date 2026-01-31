# Persist pre-commit and prek cache (persist-pre-commit-cache)

Retain the pre-commit and prek cache directories across container rebuilds to speed up hook initialization and dependency resolution.

## What this feature does

This feature persists two cache directories that pre-commit and prek use:

- `~/.cache/pre-commit/` – Repository cache and hook data
- `~/.cache/prek/` – Prek-specific cache (if prek is installed)

Both caches are mounted as persistent Docker volumes that are shared across all users and workspaces, allowing cache reuse across container rebuilds.

### Why separate cache directories?

- **Pre-commit cache** (`~/.cache/pre-commit/`): Contains repository Git clones and hook metadata. This is portable and benefits from persistence.
- **Prek cache** (`~/.cache/prek/`): Prek's own hook and configuration cache. Maintained separately to keep caching strategies independent.

## How it works

### Build phase (as root)

The `install.sh` script creates two Docker volumes and mount points:
- `/.persist-precommit-cache` – Volume for pre-commit cache
- `/.persist-prek-cache` – Volume for prek cache

Both directories are created with permissions `777` so all users can access them.

### User initialization phase (in user context)

The `persist-precommit-init.sh` script (runs via `postCreateCommand`) performs:

1. **Backup of existing data**: If `~/.cache/pre-commit` or `~/.cache/prek` exist as regular directories, they are renamed to `.bak` (preserving any existing cache).
2. **Symlink creation**: Creates symlinks from `~/.cache/pre-commit` and `~/.cache/prek` to the persistent volumes.

This approach ensures:
- **No data loss**: Existing caches are backed up before being replaced
- **Automatic recovery**: Symlinks persist across rebuilds; no repeated setup needed
- **Multi-user support**: All users can access the shared volumes

## Example Usage

```json
"features": {
    "ghcr.io/ckagerer/devcontainer-features/persist-pre-commit-cache:1": {
        "keep_going": false
    }
}
```

## Options

### `keep_going` (boolean, default: `false`)

If set to `true`, the installer will not fail on errors and will attempt to continue setup. Useful for troubleshooting or environments with unusual configurations.

## Performance benefits

Typical pre-commit initialization includes:

1. Cloning hook repositories from GitHub (~5-30 MB, network latency)
2. Installing hook dependencies (Python packages, system libraries)
3. Building and caching hook environments

With persistent cache volumes, subsequent container rebuilds skip steps 1-2 entirely, reducing rebuild time by 60-80% depending on the number and size of hooks.

## Requirements

- Pre-commit must be installed (typically via a separate feature or `postCreateCommand`)
- Write permissions to `~/.cache/` (normally available in user context)
- Docker volumes support (standard in dev container environments)

## Troubleshooting

### Symlinks not created

Check that the `persist-precommit-init.sh` script ran without errors:

```bash
# View logs of the postCreateCommand
# This is typically shown in the dev container build output
```

### Cache still not persisting

Verify the volume mounts are active:

```bash
# Inside the container
mount | grep persist
# Should show:
# devcontainer-persist-precommit-cache on /.persist-precommit-cache
# devcontainer-persist-prek-cache on /.persist-prek-cache
```

### Clearing old cache data

If you need to reset cached data:

```bash
# Inside the container (as user)
rm ~/.cache/pre-commit.bak ~/.cache/prek.bak  # Remove backups
rm -rf ~/.cache/pre-commit ~/.cache/prek       # This will remove symlinks too
```

Then rebuild the dev container to recreate fresh symlinks.

## Related features

- [persist-shell-history](../persist-shell-history/) – Persist bash/zsh history across rebuilds
- [chezmoi](../chezmoi/) – Dotfile management (often used with pre-commit)
