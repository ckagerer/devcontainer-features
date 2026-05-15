#!/usr/bin/env sh
# (C) Copyright 2026 Christian Kagerer
# Purpose: Persist claude-mem knowledge base across container rebuilds via named Docker volume

set -eu

STAGE_DIR="/.persist-claude-mem"

# Pre-create staging dir so Docker volume inherits world-writable permissions on first mount.
# Without this, the volume would default to root:root 755 and non-root users could not write.
mkdir -p "${STAGE_DIR}"
chmod 777 "${STAGE_DIR}"

INIT_SCRIPT_PATH="/usr/local/share/persist-claude-mem-init.sh"

tee "${INIT_SCRIPT_PATH}" >/dev/null <<'EOF'
#!/usr/bin/env sh
# (C) Copyright 2026 Christian Kagerer
set -eu

STAGE="/.persist-claude-mem"
DEST="${HOME}/.claude-mem"

mkdir -p "${STAGE}"
mkdir -p "$(dirname "${DEST}")"

if [ -e "${DEST}" ] && [ ! -L "${DEST}" ]; then
    mv "${DEST}" "${DEST}.pre-persist.$(date +%s)"
elif [ -L "${DEST}" ]; then
    # -e returns false for dangling symlinks; -L catches them
    rm "${DEST}"
fi

ln -s "${STAGE}" "${DEST}"

echo "[persist-claude-mem] linked ${DEST} -> ${STAGE}"
echo "[persist-claude-mem] init complete"
EOF

chmod 755 "${INIT_SCRIPT_PATH}"

echo "Done"
