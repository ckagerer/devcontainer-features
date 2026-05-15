# Devcontainer: Share Host AI Agent Configs (Bind-Mount + Selective Symlinks)

## Context

Claude Code runs inside devcontainers built by `devcontainer-features` (chezmoi installs your dotfiles). Each rebuild loses agent auth, auto-memory, user-level `CLAUDE.md`, custom commands/agents/skills, keybindings, and session state. Support for additional agents (Copilot, Skillshare) is deferred to future releases.

Goal: a feature that **shares the host's Claude Code config** into the devcontainer via bind-mount, while **isolating volatile or environment-specific subpaths** (plugins with native bins, MCP server configs referencing host-only commands, per-instance session state).

## Naming

Existing `persist-*` features = named docker volumes (persistence layer in docker). New features = host bind-mounts (different semantic). New prefix: **`share-host-*`**.

**v0.1 scope:** `share-host-claude-config` only.

**Deferred (future):**
- `share-host-copilot-config`
- `share-host-skillshare-config`
- `share-host-codex-config`, `share-host-gemini-config`, `share-host-cursor-config`

## Design: Staging Bind-Mount + Selective Symlinks

Pure whole-dir bind hits an MCP/plugins problem: host `settings.json` may launch MCP servers via host-only commands; `~/.claude/plugins/` may hold native binaries; container projects may want their own MCP setup. Solution:

1. Bind-mount the entire host directory at a **staging path** (e.g. `/.host-claude`). One mount, simple.
2. Init script (postCreate) builds `$HOME/.claude` as a real directory and symlinks **only the safe, opt-in subpaths** from the staging mount into it.
3. Container-owned subpaths (plugins, MCP config, settings.json, projects, statsig db) stay container-local — host config doesn't leak in, container churn doesn't leak out.
4. Each linkable subpath is a feature option, default chosen for "safe + high value".

### Default symlink set — `share-host-claude-config`

Host `~/.claude` → `/.host-claude`. Default link set is keyed to the actual layout of the user's `~/.claude` (real inventory: `agents/`, `backups/`, `cache/`, `commands/`, `context-mode/`, `downloads/`, `file-history/`, `hooks/`, `paste-cache/`, `plans/`, `plugins/`, `projects/`, `rules/`, `session-env/`, `sessions/`, `shell-snapshots/`, `skills/`, `tasks/`, `telemetry/`, plus top-level files).

| Subpath | Default | Option | Why |
|---|---|---|---|
| `CLAUDE.md` | link | `link_claude_md` | User-level instructions. |
| `agents/` | link | `link_agents` | Subagent defs. Markdown. |
| `commands/` | link | `link_commands` | Slash commands. |
| `skills/` | link | `link_skills` | User skills. |
| `hooks/` | link | `link_hooks` | User-level hook scripts. Must be in container for hooks to fire. |
| `rules/` | link | `link_rules` | User-level rules. |
| `plugins/` | link | `link_plugins` | Single plugin registry across host + containers. Same x86_64 Linux assumed. See arch caveat. |
| `sessions/` | **no link** | `link_sessions` | Replayable session logs. Opt in for cross-container resume + analytics. Encoded paths differ host vs container → separate sub-dirs, no collision. |
| `projects/` | **no link** | `link_projects` | Transcript JSONLs (+ nested per-workspace `memory/`). Opt in for token-analytics (`ccusage`, `claude-cost`) or to share auto-memory cross-environment (memory only matches if `workspaceFolder` encoded path matches — see Cons). |
| `tasks/` | **no link** | `link_tasks` | Per-session task lists. |
| `history.jsonl` | **no link** | `link_history` | Prompt history. Append-mostly; opt in for cross-container continuity. |
| `claude.json` | **no link** | `link_claude_json` | Main per-install state. Often references local paths and IDs — risky to share. Opt in only if portable. |
| `settings.json` | **no link** | `link_settings` | May reference host-only MCP server commands. |
| `mcp_servers.json` / `.mcp.json` | **no link** | — | Container picks its own MCP servers. |
| `.credentials.json` | **no link** | — | Claude auth injected via env var (`ANTHROPIC_API_KEY` / equivalent). Out of scope. |
| `cache/`, `paste-cache/`, `downloads/`, `file-history/`, `session-env/`, `shell-snapshots/`, `plans/`, `context-mode/`, `backups/` | **no link** | — | Volatile, per-instance, transient. |
| `telemetry/`, `stats-cache.json` | **no link** | — | Local telemetry. May hold sqlite — concurrent host+container writes risk lock contention. |
| `RTK.md`, `statusline-command.sh`, `.caveman-active`, `.deep-link-register-failed`, `.last-cleanup`, `settings.json.bak` | **no link** | — | Host-host-local helpers and runtime markers. Container provides its own statusline/RTK setup if needed. |
| `settings.local.json` | **no link** | — | Per-workspace overrides. |

Feature option names (booleans) in `devcontainer-feature.json` use snake_case (e.g., `link_claude_md`) and map 1:1 to the `Option` column above. Defaults match the `Default` column. Claude auth is **not** managed by this feature — inject via env var (`containerEnv` in `devcontainer.json`).

**Token / usage analytics use-case:** if you run tools like `ccusage` or `claude-cost` against `~/.claude/projects/` (or `~/.claude/sessions/`), set `link_projects: true` and/or `link_sessions: true` on every container that uses Claude so transcripts land in one place. Each workspace gets a distinct encoded sub-dir (`-workspaces-<repo>` vs `-home-<user>-projects-<repo>`) — no transcript collision, the analytics tool sums across both.

**Auto-memory cross-environment:** auto-memory lives at `~/.claude/projects/<encoded-workspace>/memory/`, not top-level. Sharing memory between host and container requires either (a) `link_projects: true` **plus** identical encoded workspace path (set `workspaceFolder` in `devcontainer.json` to match the host path, e.g. `/home/ckagerer/projects/<repo>`), or (b) accept per-environment memory.

## Install Scripts — Exact Behavior

### `install.sh` (build-time, runs as root)
1. `set -euo pipefail`
2. Create staging dir placeholder: `mkdir -p /.host-claude && chmod 1777 /.host-claude` (matches `persist-shell-history` convention — top-level path, world-writable so any container user can traverse before the mount overrides it).
3. Read feature options from env vars (devcontainer-features auto-exports options as uppercase env: `link_claude_md` → `LINK_CLAUDE_MD`). Inject them into init script via sed replacement at build time (so user-context post-create can read them without env propagation issues).
4. Emit `/usr/local/share/share-host-claude-config-init.sh` with the link logic below; `chmod +x` it.
5. Done. No package installs.

**Option injection pattern (from persist-ccache-cache):**
```sh
# In install.sh:
INIT_SCRIPT_PATH="/usr/local/share/share-host-claude-config-init.sh"

tee "$INIT_SCRIPT_PATH" >/dev/null <<'EOF'
#!/usr/bin/env sh
set -eu
# ... init logic ...
LINK_CLAUDE_MD="__LINK_CLAUDE_MD_PLACEHOLDER__"
LINK_AGENTS="__LINK_AGENTS_PLACEHOLDER__"
# ... etc for each option ...
EOF

# Inject build-time option values into placeholders:
sed -i "s|__LINK_CLAUDE_MD_PLACEHOLDER__|${LINK_CLAUDE_MD:-true}|g" "$INIT_SCRIPT_PATH"
sed -i "s|__LINK_AGENTS_PLACEHOLDER__|${LINK_AGENTS:-true}|g" "$INIT_SCRIPT_PATH"
# ... etc ...

chmod 755 "$INIT_SCRIPT_PATH"
```
Then in the init script (lines 129–142 below), use the injected values directly.

### `share-host-claude-config-init.sh` (post-create, runs as container user via `postCreateCommand`)
```sh
#!/usr/bin/env sh
set -eu

STAGE="/.host-claude"
DEST="$HOME/.claude"

# 1. Mount sanity
if ! mountpoint -q "$STAGE"; then
  echo "[share-host-claude-config] ERROR: $STAGE not a mountpoint. Verify devcontainer.json mounts section includes host bind. Refusing to continue." >&2
  exit 1
fi

# 2. UID assert — staging owner must match current user
stage_uid="$(stat -c %u "$STAGE")"
my_uid="$(id -u)"
if [ "$stage_uid" != "$my_uid" ]; then
  echo "[share-host-claude-config] UID mismatch: stage=$stage_uid me=$my_uid. Refusing to symlink." >&2
  echo "                            Set updateRemoteUserUID: true and rebuild." >&2
  exit 1
fi

# 3. Prepare DEST as real dir (preserve any container-installed content)
if [ -L "$DEST" ]; then
  # Old symlink from a prior run — remove
  rm "$DEST"
fi
mkdir -p "$DEST"

# 4. For each enabled subpath: backup existing, then symlink
link_subpath() {
  name="$1"
  src="$STAGE/$name"
  dst="$DEST/$name"
  [ -e "$src" ] || { echo "[share-host-claude-config] host has no $name, skip"; return 0; }
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.pre-share.$(date +%s)"
  elif [ -L "$dst" ]; then
    rm "$dst"
  fi
  ln -s "$src" "$dst"
  echo "[share-host-claude-config] linked $name"
}

# Baked-in defaults from install.sh options (injected via sed):
# --- linked by default (high-value, low-risk) ---
[ "${LINK_CLAUDE_MD:-true}"    = "true" ] && link_subpath CLAUDE.md
[ "${LINK_AGENTS:-true}"       = "true" ] && link_subpath agents
[ "${LINK_COMMANDS:-true}"     = "true" ] && link_subpath commands
[ "${LINK_SKILLS:-true}"       = "true" ] && link_subpath skills
[ "${LINK_HOOKS:-true}"        = "true" ] && link_subpath hooks
[ "${LINK_RULES:-true}"        = "true" ] && link_subpath rules
[ "${LINK_PLUGINS:-true}"      = "true" ] && link_subpath plugins
# --- opt-in (default false) ---
[ "${LINK_SESSIONS:-false}"    = "true" ] && link_subpath sessions
[ "${LINK_PROJECTS:-false}"    = "true" ] && link_subpath projects
[ "${LINK_TASKS:-false}"       = "true" ] && link_subpath tasks
[ "${LINK_HISTORY:-false}"     = "true" ] && link_subpath history.jsonl
[ "${LINK_CLAUDE_JSON:-false}" = "true" ] && link_subpath claude.json
[ "${LINK_SETTINGS:-false}"    = "true" ] && link_subpath settings.json
```

## Pros / Cons

### Pros
- **Solves the MCP / plugins concern** — container has its own `settings.json`, `plugins/`, and MCP config by default; host doesn't override.
- **Skills, commands, and agents persist** across host + every container. Memory persistence requires `link_projects: true` plus matching `workspaceFolder` — see Auto-memory note.
- **One staging mount per feature** — clean, mirrors `persist-*` ergonomics, just bind-mount instead of named volume.
- **Per-subpath control via options** — opt into `link_settings`, `link_plugins` if portable.
- **chezmoi-compatible** — chezmoi writes host paths; container sees results via mount.
- **Composable** — opt in per project's `devcontainer.json`; additional agent features deferred to future releases.
- **Container divergence allowed** — container can install its own plugins/MCP/skills without touching host.

### Cons + Mitigations
| Risk | Mitigation |
|---|---|
| `link_settings: true` and host `settings.json` references host-only MCP commands → MCP launch fails inside container | Default off. Document. Suggest splitting MCP config into `.mcp.json` per-project (already container-portable). |
| `link_plugins: true` (default) — if a plugin ships native binaries built for host arch and container arch differs (e.g. host x86_64, container arm64), plugin crashes | Default works for typical case (Linux x86_64 host + container). Document caveat in README + provide `link_plugins: false` opt-out for cross-arch containers. |
| `link_plugins: true` — container `claude plugin install/uninstall` mutates host registry | Intentional (single registry across host + containers). Document. Simultaneous `plugin install` from multiple containers is not safe — run plugin management from host or one container at a time. |
| `.credentials.json` readable by anything in container | Not applicable — Claude auth not handled by this feature. Inject via `containerEnv` env var. Standard env-var sensitivity rules apply (don't echo, don't log). |
| Auto-memory (`projects/<encoded>/memory/`) is only shared if `link_projects: true` **and** container `workspaceFolder` matches host workspace path | Document. Suggest devcontainer.json `"workspaceFolder": "/home/${localEnv:USER}/projects/<repo>"` mapping for cross-environment memory continuity. Otherwise accept per-environment memory. |
| Concurrent writes to shared append files (`history.jsonl`, nested `memory/*.md`) from host + container | Append-mostly, infrequent collisions. Document: avoid simultaneous interactive sessions on the same file. |
| chezmoi writes `$HOME/.claude/settings.json` before mount is active (install runs before our init) → if `link_settings` on, might link stale data | Intentional design. Chezmoi first (build-time), init second (post-create). Init backs up any pre-existing `~/.claude` content (including chezmoi-written files) before symlinking. Default `link_settings: false` prevents linking potentially host-specific config. |
| UID mismatch breaks writes | Init script asserts and fails loud. `updateRemoteUserUID: true` required. |
| Existing `$HOME/.claude` from base image | Init script preserves: real dir kept; each linked subpath backed up to `.pre-share.<ts>` before symlink. Non-linked subpaths remain container-local untouched. |
| Linux-only assumption | All current targets Linux. Document. |
| Encoded project paths differ host vs container → "resume session" doesn't cross | Acceptable; `projects/` not linked. |

## File Layout

```
src/
└── share-host-claude-config/
    ├── devcontainer-feature.json
    ├── install.sh
    └── README.md
test/
└── share-host-claude-config/
    ├── scenarios.json
    └── test.sh
```

### `devcontainer-feature.json` (share-host-claude-config sketch)
```json
{
  "id": "share-host-claude-config",
  "version": "0.1.0",
  "name": "Share host Claude Code config",
  "description": "Bind-mounts the host ~/.claude into the devcontainer and selectively symlinks safe subpaths (memory, commands, agents, skills, ...) into $HOME/.claude so memory and user prefs persist across rebuilds. MCP/settings.json excluded by default; plugins linked by default.",
  "options": {
    "link_claude_md":    { "type": "boolean", "default": true },
    "link_agents":       { "type": "boolean", "default": true },
    "link_commands":     { "type": "boolean", "default": true },
    "link_skills":       { "type": "boolean", "default": true },
    "link_hooks":        { "type": "boolean", "default": true },
    "link_rules":        { "type": "boolean", "default": true },
    "link_plugins":      { "type": "boolean", "default": true },
    "link_sessions":     { "type": "boolean", "default": false },
    "link_projects":     { "type": "boolean", "default": false },
    "link_tasks":        { "type": "boolean", "default": false },
    "link_history":      { "type": "boolean", "default": false },
    "link_claude_json":  { "type": "boolean", "default": false },
    "link_settings":     { "type": "boolean", "default": false }
  },
  "mounts": [
    {
      "source": "${localEnv:HOME}/.claude",
      "target": "/.host-claude",
      "type": "bind"
    }
  ],
  "postCreateCommand": "/usr/local/share/share-host-claude-config-init.sh",
  "installsAfter": ["ghcr.io/<owner>/devcontainer-features/chezmoi"]
  // Replace <owner> with the actual registry org before use.
}
```

### Reuse (don't reinvent)
- Skeleton + init-script emission: copy from `src/persist-shell-history/install.sh`.
- Test layout + `scenarios.json` shape: copy from `test/persist-shell-history/`.
- AGENTS.md: repo root.

## Root Docs
- Add one row to root `README.md` for `share-host-claude-config`.
- This doc lives at `docs/devcontainer-persistent-ai-agent-configs.md`.

## Verification (per feature)

1. `devcontainer features test --features share-host-claude-config`.
2. Fixture workspace + new feature → `devcontainer up`, then:
   - `devcontainer exec -- mountpoint /.host-claude` → success.
   - `devcontainer exec -- readlink ~/.claude/skills` → `/.host-claude/skills` (default-linked).
   - `devcontainer exec -- readlink ~/.claude/hooks` → `/.host-claude/hooks` (default-linked).
   - `devcontainer exec -- readlink ~/.claude/rules` → `/.host-claude/rules` (default-linked).
   - `devcontainer exec -- readlink ~/.claude/plugins` → `/.host-claude/plugins` (default-linked).
   - `devcontainer exec -- test ! -L ~/.claude/sessions` → true (opt-in, not linked by default).
   - `devcontainer exec -- claude --version` → starts (auth via env var, not this feature).
3. Round-trip on a linked subpath: in container, `echo "rt-$(date +%s)" >> ~/.claude/rules/test.md`; on host, `tail ~/.claude/rules/test.md` shows the line. Clean up.
4. Plugin propagation: in container `claude plugin install <x>`; verify host `~/.claude/plugins/<x>` now exists.
4b. Cross-arch sanity (manual): set `link_plugins: false` for an arm64 container fixture → `~/.claude/plugins` is container-local, no host writes.
5. Existing `~/.claude/CLAUDE.md` from base image: must be moved to `CLAUDE.md.pre-share.<ts>` and replaced by symlink.
6. UID mismatch fixture: set `containerUser` to uid that doesn't match host → init script must exit non-zero and not symlink.
7. chezmoi order: with chezmoi feature in same `devcontainer.json`, end state must show symlinks present (init ran after chezmoi).
8. `link_sessions: true` opt-in fixture → `~/.claude/sessions` is symlink; run `claude` briefly, exit; on host `ls ~/.claude/sessions/` shows the new session log.
9. `link_projects: true` opt-in fixture with matching `workspaceFolder` → run a Claude session, exit; on host the same encoded sub-dir under `~/.claude/projects/` contains the JSONL transcript → verify ccusage sees it.
10. `link_settings: true` opt-in fixture → settings.json symlinked, container writes propagate to host (verify with a no-op key add).

## Open Decisions Before Coding

1. Confirm naming: `share-host-*` (recommended) vs alternatives (`bind-host-*`, `host-*-config`). ✓ Chosen: `share-host-*`.
2. v0.1 ships `share-host-claude-config` only. Copilot, Skillshare, Codex/Gemini/Cursor stubs deferred to later.

## Implementation Notes

- **Option passing**: Use sed injection pattern (see install.sh section above). Copy from `src/persist-ccache-cache/install.sh` for reference.
- **Mount failure**: Init script exits 1 (loud fail). Users must fix bind configuration in devcontainer.json mounts section.
- **Chezmoi ordering**: Intentional two-stage: chezmoi writes at build time, our init runs post-create and backs up any pre-existing content before symlinking. No ordering constraint needed beyond default devcontainer-features ordering.
