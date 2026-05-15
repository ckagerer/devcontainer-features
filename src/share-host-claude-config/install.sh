#!/usr/bin/env sh
# (C) Copyright 2026 Christian Kagerer
# Purpose: Bind-mount host ~/.claude and selectively symlink safe subpaths into container $HOME/.claude

set -eu

STAGE="/.host-claude"
INIT_SCRIPT_PATH="/usr/local/share/share-host-claude-config-init.sh"

# Create staging dir placeholder — bind mount overrides at runtime
mkdir -p "${STAGE}"
chmod 1777 "${STAGE}"

# Emit the postCreateCommand init script
tee "$INIT_SCRIPT_PATH" >/dev/null <<'EOF'
#!/usr/bin/env sh
set -eu

STAGE="/.host-claude"
DEST="$HOME/.claude"

# 1. Mount sanity (skippable in tests via SKIP_MOUNT_CHECK=true)
if [ "${SKIP_MOUNT_CHECK:-false}" != "true" ]; then
    if ! mountpoint -q "$STAGE"; then
        echo "[share-host-claude-config] ERROR: $STAGE not a mountpoint. Verify devcontainer.json mounts section includes host bind. Refusing to continue." >&2
        exit 1
    fi
fi

# 2. UID assert — staging owner must match current user (root is exempt)
if [ "${SKIP_UID_CHECK:-false}" != "true" ] && [ "$(id -u)" != "0" ]; then
    stage_uid="$(stat -c %u "$STAGE")"
    my_uid="$(id -u)"
    if [ "$stage_uid" != "$my_uid" ]; then
        echo "[share-host-claude-config] UID mismatch: stage=$stage_uid me=$my_uid. Refusing to symlink." >&2
        echo "                            Set updateRemoteUserUID: true and rebuild." >&2
        exit 1
    fi
fi

# 3. Prepare DEST as real dir (preserve any container-installed content)
if [ -L "$DEST" ]; then
    rm "$DEST"
fi
mkdir -p "$DEST"

# 4. For each enabled subpath: backup existing real content, then symlink
link_subpath() {
    name="$1"
    src="$STAGE/$name"
    dst="$DEST/$name"
    if [ ! -e "$src" ]; then
        echo "[share-host-claude-config] host has no $name, skip"
        return 0
    fi
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mv "$dst" "${dst}.pre-share.$(date +%s)"
    elif [ -L "$dst" ]; then
        rm "$dst"
    fi
    ln -s "$src" "$dst"
    echo "[share-host-claude-config] linked $name"
}

# Baked-in option values (injected by install.sh via sed):
LINK_CLAUDE_MD="__LINK_CLAUDE_MD__"
LINK_AGENTS="__LINK_AGENTS__"
LINK_COMMANDS="__LINK_COMMANDS__"
LINK_SKILLS="__LINK_SKILLS__"
LINK_HOOKS="__LINK_HOOKS__"
LINK_RULES="__LINK_RULES__"
LINK_PLUGINS="__LINK_PLUGINS__"
LINK_SESSIONS="__LINK_SESSIONS__"
LINK_PROJECTS="__LINK_PROJECTS__"
LINK_TASKS="__LINK_TASKS__"
LINK_HISTORY="__LINK_HISTORY__"
LINK_CLAUDE_JSON="__LINK_CLAUDE_JSON__"
LINK_SETTINGS="__LINK_SETTINGS__"

# linked by default (high-value, low-risk)
[ "$LINK_CLAUDE_MD"   = "true" ] && link_subpath CLAUDE.md
[ "$LINK_AGENTS"      = "true" ] && link_subpath agents
[ "$LINK_COMMANDS"    = "true" ] && link_subpath commands
[ "$LINK_SKILLS"      = "true" ] && link_subpath skills
[ "$LINK_HOOKS"       = "true" ] && link_subpath hooks
[ "$LINK_RULES"       = "true" ] && link_subpath rules
[ "$LINK_PLUGINS"     = "true" ] && link_subpath plugins
# opt-in (default false)
[ "$LINK_SESSIONS"    = "true" ] && link_subpath sessions
[ "$LINK_PROJECTS"    = "true" ] && link_subpath projects
[ "$LINK_TASKS"       = "true" ] && link_subpath tasks
[ "$LINK_HISTORY"     = "true" ] && link_subpath history.jsonl
[ "$LINK_CLAUDE_JSON" = "true" ] && link_subpath claude.json
[ "$LINK_SETTINGS"    = "true" ] && link_subpath settings.json

echo "[share-host-claude-config] init complete"
EOF

# Inject build-time option values
sed -i "s|__LINK_CLAUDE_MD__|${link_claude_md:-true}|g" "$INIT_SCRIPT_PATH"
sed -i "s|__LINK_AGENTS__|${link_agents:-true}|g" "$INIT_SCRIPT_PATH"
sed -i "s|__LINK_COMMANDS__|${link_commands:-true}|g" "$INIT_SCRIPT_PATH"
sed -i "s|__LINK_SKILLS__|${link_skills:-true}|g" "$INIT_SCRIPT_PATH"
sed -i "s|__LINK_HOOKS__|${link_hooks:-true}|g" "$INIT_SCRIPT_PATH"
sed -i "s|__LINK_RULES__|${link_rules:-true}|g" "$INIT_SCRIPT_PATH"
sed -i "s|__LINK_PLUGINS__|${link_plugins:-true}|g" "$INIT_SCRIPT_PATH"
sed -i "s|__LINK_SESSIONS__|${link_sessions:-false}|g" "$INIT_SCRIPT_PATH"
sed -i "s|__LINK_PROJECTS__|${link_projects:-false}|g" "$INIT_SCRIPT_PATH"
sed -i "s|__LINK_TASKS__|${link_tasks:-false}|g" "$INIT_SCRIPT_PATH"
sed -i "s|__LINK_HISTORY__|${link_history:-false}|g" "$INIT_SCRIPT_PATH"
sed -i "s|__LINK_CLAUDE_JSON__|${link_claude_json:-false}|g" "$INIT_SCRIPT_PATH"
sed -i "s|__LINK_SETTINGS__|${link_settings:-false}|g" "$INIT_SCRIPT_PATH"

chmod 755 "$INIT_SCRIPT_PATH"

echo "Done"
