#!/usr/bin/env sh
# (C) Copyright 2026 Christian Kagerer
# Purpose: Bind-mount host ~/.config/skillshare and symlink it into container $HOME/.config/skillshare

set -eu

STAGE="/.host-skillshare-config"
INIT_SCRIPT_PATH="/usr/local/share/share-host-skillshare-config-init.sh"

# Create staging dir placeholder — bind mount overrides at runtime
mkdir -p "${STAGE}"
chmod 1777 "${STAGE}"

# Emit the postCreateCommand init script
tee "$INIT_SCRIPT_PATH" >/dev/null <<'EOF'
#!/usr/bin/env sh
set -eu

STAGE="/.host-skillshare-config"
DEST="$HOME/.config/skillshare"

# 1. Mount sanity (skippable in tests via SKIP_MOUNT_CHECK=true)
if [ "${SKIP_MOUNT_CHECK:-false}" != "true" ]; then
    if ! mountpoint -q "$STAGE"; then
        echo "[share-host-skillshare-config] ERROR: $STAGE not a mountpoint. Verify devcontainer.json mounts section includes host bind. Refusing to continue." >&2
        exit 1
    fi
fi

# 2. UID assert — staging owner must match current user (root is exempt)
if [ "${SKIP_UID_CHECK:-false}" != "true" ] && [ "$(id -u)" != "0" ]; then
    stage_uid="$(stat -c %u "$STAGE")"
    my_uid="$(id -u)"
    if [ "$stage_uid" != "$my_uid" ]; then
        echo "[share-host-skillshare-config] UID mismatch: stage=$stage_uid me=$my_uid. Refusing to symlink." >&2
        echo "                               Set updateRemoteUserUID: true and rebuild." >&2
        exit 1
    fi
fi

# 3. Backup existing real dir, then replace with symlink to staging
mkdir -p "$(dirname "$DEST")"
if [ -e "$DEST" ] && [ ! -L "$DEST" ]; then
    mv "$DEST" "${DEST}.pre-share.$(date +%s)"
elif [ -L "$DEST" ]; then
    rm "$DEST"
fi
ln -s "$STAGE" "$DEST"

echo "[share-host-skillshare-config] linked $DEST -> $STAGE"
echo "[share-host-skillshare-config] init complete"
EOF

chmod 755 "$INIT_SCRIPT_PATH"

echo "Done"
