# Persist ccache compiler cache (persist-ccache)

Retain the ccache compiler cache directory across container rebuilds to speed up C/C++ compilation by reusing cached compilation results.

## What this feature does

This feature persists the ccache cache directory across container rebuilds:

- `~/.cache/ccache/` – ccache compiler cache

The cache is mounted as a persistent Docker volume that is shared across all users and workspaces, allowing cache reuse across container rebuilds.

## How it works

### Build phase (as root)

The `install.sh` script creates a Docker volume and mount point:
- `/.persist-ccache` – Volume for ccache cache

The directory is created with permissions `777` so all users can access it.

### User initialization phase (in user context)

The `persist-ccache-init.sh` script (runs via `postCreateCommand`) performs:

1. **Backup of existing data**: If `~/.cache/ccache` exists as a regular directory, it is renamed to `.bak` (preserving any existing cache).
2. **Symlink creation**: Creates a symlink from `~/.cache/ccache` to the persistent volume.
3. **Environment configuration**: Sets `CCACHE_DIR` and `CCACHE_MAXSIZE` environment variables.
4. **Shell integration**: Adds environment variables to `~/.bashrc` and `~/.zshrc` if they exist.

This approach ensures:
- **No data loss**: Existing caches are backed up before being replaced
- **Automatic recovery**: Symlinks persist across rebuilds; no repeated setup needed
- **Multi-user support**: All users can access the shared volume
- **Proper configuration**: Environment variables are set in the container so ccache knows where to store/find cache

## Example Usage

```json
"features": {
    "ghcr.io/ckagerer/devcontainer-features/persist-ccache:1": {
        "cache_size": "5G"
    }
}
```

## Options

### `cache_size` (string, default: `"5G"`)

Sets the maximum size of the ccache cache. Valid formats include:
- Decimal: `kB`, `MB`, `GB`, `TB` (e.g., `10GB`)
- Binary: `KiB`, `MiB`, `GiB`, `TiB` (e.g., `5GiB`)

Examples:
- `"5G"` (default) – 5 gigabytes
- `"10GB"` – 10 gigabytes
- `"100G"` – 100 gigabytes
- `"50GiB"` – 50 gibibytes (binary)

### `keep_going` (boolean, default: `false`)

If set to `true`, the installer will not fail on errors and will attempt to continue setup. Useful for troubleshooting or environments with unusual configurations.

## Performance benefits

Typical ccache initialization includes:

1. Creating cache directory structure
2. Configuring cache limits
3. Initializing cache database

With persistent cache volumes, subsequent container rebuilds skip setup entirely and can immediately reuse cached compilation results. Depending on your project, this can reduce build times by 50-90% on subsequent builds.

## Requirements

- C/C++ build tools using ccache (optional; feature sets up infrastructure even if ccache is not yet installed)
- Write permissions to `~/.cache/` (normally available in user context)
- Docker volumes support (standard in dev container environments)

## Environment Variables

The feature automatically sets:

- `CCACHE_DIR=~/.cache/ccache` – Location of the cache
- `CCACHE_MAXSIZE=<cache_size>` – Maximum cache size

These are set in user shell RC files (`.bashrc`, `.zshrc`) for persistence across shell sessions.

## Troubleshooting

### Symlinks not created

Check that the `persist-ccache-init.sh` script ran without errors:

```bash
# View logs of the postCreateCommand
# This is typically shown in the dev container build output
```

### Cache still not persisting

Verify the volume mount is active:

```bash
# Inside the container
mount | grep persist-ccache
# Should show:
# devcontainer-persist-ccache on /.persist-ccache
```

Verify environment variables are set:

```bash
echo $CCACHE_DIR
echo $CCACHE_MAXSIZE
```

### Clearing old cache data

If you need to reset cached data:

```bash
# Inside the container (as user)
rm ~/.cache/ccache.bak  # Remove backups if any
rm -rf ~/.cache/ccache   # This will remove symlink too
```

Then rebuild the dev container to recreate fresh symlinks.

### Checking cache statistics

```bash
# Show cache statistics and current configuration
ccache -s

# Show compression statistics
ccache -x

# Clear the cache if needed
ccache -C
```

## Related features

- [persist-shell-history](../persist-shell-history/) – Persist bash/zsh history across rebuilds
- [persist-pre-commit-cache](../persist-pre-commit-cache/) – Persist pre-commit hook cache across rebuilds
- [clang](../clang/) – Install clang/LLVM toolchain
