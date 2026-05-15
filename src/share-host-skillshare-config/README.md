# Share host Skillshare config (share-host-skillshare-config)

Bind-mounts the host `~/.config/skillshare` into the devcontainer at `/.host-skillshare-config` and symlinks it into `$HOME/.config/skillshare` so Skillshare skills, extras, and agents persist across rebuilds.

## Example Usage

```json
"features": {
    "ghcr.io/ckagerer/devcontainer-features/share-host-skillshare-config:0": {}
}
```

## Notes

### config.yaml target paths

Host `config.yaml` may reference target paths (e.g. `~/.claude/skills`, `~/.cursor/rules`) that do not exist in the container. `skillshare sync` inside the container will skip non-existent targets gracefully. Skills remain fully readable by AI CLIs that resolve their own path independently (e.g. `share-host-claude-config` already links `~/.claude/skills` from the same host source).

### Skillshare auth / network

This feature does not configure Skillshare authentication or network access. Installs and updates requiring network access must be run from the host.
