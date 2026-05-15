# Share host Claude Code config (share-host-claude-config)

Bind-mounts the host `~/.claude` into the devcontainer at `/.host-claude` and selectively symlinks safe subpaths into `$HOME/.claude` so Claude Code config (agents, commands, skills, hooks, rules, plugins) persists across rebuilds. MCP config and `settings.json` excluded by default.

## Linked subpaths

| Subpath | Default | Option |
|---|---|---|
| `CLAUDE.md` | linked | `link_claude_md` |
| `agents/` | linked | `link_agents` |
| `commands/` | linked | `link_commands` |
| `skills/` | linked | `link_skills` |
| `hooks/` | linked | `link_hooks` |
| `rules/` | linked | `link_rules` |
| `plugins/` | linked | `link_plugins` |
| `sessions/` | **not linked** | `link_sessions` |
| `projects/` | **not linked** | `link_projects` |
| `tasks/` | **not linked** | `link_tasks` |
| `history.jsonl` | **not linked** | `link_history` |
| `claude.json` | **not linked** | `link_claude_json` |
| `settings.json` | **not linked** | `link_settings` |

Pre-existing container content in any linked subpath is backed up to `<name>.pre-share.<timestamp>` before the symlink is created.

## Example Usage

```json
"features": {
    "ghcr.io/ckagerer/devcontainer-features/share-host-claude-config:0": {}
}
```

All options are boolean and default to the values shown in the table above.

## Notes

### Plugin architecture

`link_plugins: true` (default) assumes the host and container share the same architecture (Linux x86\_64). Plugins that ship native binaries will crash if the architectures differ. Set `link_plugins: false` for cross-arch containers (e.g. host x86\_64, container arm64).

Concurrent `claude plugin install` or `uninstall` from multiple containers writing to the same host `plugins/` is not safe. Run plugin management from the host or one container at a time.

### Auto-memory across environments

Auto-memory lives at `~/.claude/projects/<encoded-workspace>/memory/`, not at the top level. To share memory between host and container, set `link_projects: true` **and** configure `workspaceFolder` in `devcontainer.json` to match the host workspace path exactly (e.g. `"/home/${localEnv:USER}/projects/myrepo"`). Without a matching encoded path, host and container maintain separate memory stores — which is the default behaviour.

### Usage analytics

To aggregate Claude token usage across host and containers with tools like `ccusage`, set `link_projects: true` and/or `link_sessions: true`. Each workspace gets a distinct encoded sub-directory — no transcript collision between host and container sessions.

### settings.json

`link_settings` is off by default. Host `settings.json` may reference MCP server commands that are only available on the host (e.g. host-local binaries, Docker socket paths). Enable only if your `settings.json` is portable across environments.

### Claude auth

This feature does not handle Claude authentication. Inject credentials via `containerEnv` in `devcontainer.json` (e.g. `ANTHROPIC_API_KEY`).
