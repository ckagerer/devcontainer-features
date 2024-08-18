#!/usr/bin/env bash

set -ex

CHEZMOI_USER="${CHEZMOI_USER:-$_REMOTE_USER}"

# exit if DOTFILES_REPO is not set
if [ -z "${DOTFILES_REPO}" ]; then
    echo "DOTFILES_REPO is not set"
    exit 1
fi

# update apt cache
apt update

# check if curl is installed
if ! command -v curl &>/dev/null; then
    apt install -y curl
fi

# check if sudo is installed
if ! command -v sudo &>/dev/null; then
    apt install -y sudo
fi

# check if git is installed
if ! command -v git &>/dev/null; then
    apt install -y git
fi

# cleanup apt cache
rm -rf /var/lib/apt/lists/*

# download and run the installer
INSTALLER_PATH="/tmp/chezmoi-installer.sh"
curl --fail --silent --location --show-error --retry 10 --output "$INSTALLER_PATH" https://git.io/chezmoi
chmod +x "$INSTALLER_PATH"
BINDIR="/usr/local/bin" "$INSTALLER_PATH"
rm "$INSTALLER_PATH"

# get home directory of user ${CHEZMOI_USER}
CHEZMOI_USER_HOME="$(getent passwd "${CHEZMOI_USER}" | cut -d: -f6)"

# run chezmoi
CHEZMOI_ARGS=("init" "--apply")
if [ -n "${CHEZMOI_BRANCH}" ]; then
    CHEZMOI_ARGS+=("--branch" "${CHEZMOI_BRANCH}")
fi
CMD="chezmoi ${CHEZMOI_ARGS[*]} ${DOTFILES_REPO}"
sudo --user "${CHEZMOI_USER}" bash -c "cd ${CHEZMOI_USER_HOME} && REMOTE_CONTAINERS=1 ${CMD}"

# Atuin login and sync
# --- Generate a 'pull-git-lfs-artifacts.sh' script to be executed by the 'postCreateCommand' lifecycle hook
INIT_ATUIN_SCRIPT_PATH="/usr/local/share/chezmoi-atuin-init.sh"

tee "$INIT_ATUIN_SCRIPT_PATH" >/dev/null \
    <<EOF
#!/usr/bin/env bash
set -ex

ATUIN_USER="${ATUIN_USER}"
ATUIN_PASSWORD="${ATUIN_PASSWORD}"
ATUIN_KEY="${ATUIN_KEY}"

# exit if required environment variables are not set
if [ -n "\${ATUIN_USER}" ] && [ -n "\${ATUIN_PASSWORD}" ] && [ -n "\${ATUIN_KEY}" ]; then
    # If /.persist-shell-history exists, we assume that the user wants to persist also the atuin history
    if [ -d "/.persist-shell-history" ]; then
        if [ -d ~/.local/share/atuin ]; then
            mv ~/.local/share/atuin ~/.local/share/atuin.bak
        fi
        mkdir -p /.persist-shell-history/atuin
        ln --symbolic --force /.persist-shell-history/atuin ~/.local/share
    fi

    atuin login --username "\${ATUIN_USER}" --password "\${ATUIN_PASSWORD}" --key "\${ATUIN_KEY}" || true
    atuin sync
fi
EOF

chmod 755 "$INIT_ATUIN_SCRIPT_PATH"

echo "Done"
