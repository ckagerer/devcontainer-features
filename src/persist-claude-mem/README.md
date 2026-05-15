# Persist claude-mem knowledge base (persist-claude-mem)

Mounts a named Docker volume at `~/.claude-mem` so the [claude-mem](https://github.com/NicolasMassart/claude-mem) knowledge base survives container rebuilds without conflicting with the host claude-mem MCP server process.

## Example Usage

```json
"features": {
    "ghcr.io/ckagerer/devcontainer-features/persist-claude-mem:0": {}
}
```

## How It Works

During build, the feature mounts a named Docker volume at `/.persist-claude-mem`. On first container start, `postCreateCommand` runs an init script that symlinks `~/.claude-mem -> /.persist-claude-mem`.

Volume name pattern:

```
devcontainer-<workspaceFolderBasename>-persist-claude-mem-<devcontainerId>
```

Each workspace gets its own volume, so knowledge bases from different projects stay isolated.

If `~/.claude-mem` already exists as a real directory when the container starts, the init script backs it up with a timestamp (`~/.claude-mem.pre-persist.<epoch>`) before creating the symlink.

## Notes

### Host isolation

The volume mounts at `/.persist-claude-mem`, not directly at `~/.claude-mem`. This keeps the container's knowledge base on a separate filesystem path from the host's `~/.claude-mem`, so the host claude-mem MCP server process never reads from or writes to the container volume.
