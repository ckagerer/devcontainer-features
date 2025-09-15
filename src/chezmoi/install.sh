#!/usr/bin/env sh
# (C) Copyright 2025 Christian Kagerer
# Purpose: Install chezmoi and initialize dotfiles from DOTFILES_REPO

if [ "${KEEP_GOING:-false}" = "true" ]; then
  set +e
else
  set -e
fi
set -x

CHEZMOI_USER="${CHEZMOI_USER:-$_REMOTE_USER}"

# exit if DOTFILES_REPO is not set
if [ -z "${DOTFILES_REPO}" ]; then
    echo "DOTFILES_REPO is not set"
    exit 1
fi

# Function to update and install packages on Debian-based systems
install_debian_packages() {
    apt update

    # check if curl is installed
    if ! command -v curl >/dev/null 2>&1; then
        apt install -y curl
    fi

    # check if sudo is installed
    if ! command -v sudo >/dev/null 2>&1; then
        apt install -y sudo
    fi

    # check if git is installed
    if ! command -v git >/dev/null 2>&1; then
        apt install -y git
    fi

    # check if bash is installed
    if ! command -v bash >/dev/null 2>&1; then
        apt install -y bash
    fi

    # cleanup apt cache
    rm -rf /var/lib/apt/lists/*
}

# Function to update and install packages on Alpine Linux
install_alpine_packages() {
    # check if curl is installed
    if ! command -v curl >/dev/null 2>&1; then
        apk add --no-cache curl
    fi

    # check if sudo is installed
    if ! command -v sudo >/dev/null 2>&1; then
        apk add --no-cache sudo
    fi

    # check if git is installed
    if ! command -v git >/dev/null 2>&1; then
        apk add --no-cache git
    fi

    # check if bash is installed
    if ! command -v bash >/dev/null 2>&1; then
        apk add --no-cache bash
    fi
}

# Detect the distribution and install packages accordingly
if [ -f /etc/debian_version ]; then
    install_debian_packages
elif [ -f /etc/alpine-release ]; then
    install_alpine_packages
else
    echo "Unsupported distribution"
    exit 1
fi

# download and run the installer
INSTALLER_PATH="/tmp/chezmoi-installer.sh"
curl --fail --silent --location --show-error --retry 10 --output "$INSTALLER_PATH" https://git.io/chezmoi
chmod +x "$INSTALLER_PATH"
BINDIR="/usr/local/bin" "$INSTALLER_PATH"
rm "$INSTALLER_PATH"

# get home directory of user ${CHEZMOI_USER}
CHEZMOI_USER_HOME="$(getent passwd "${CHEZMOI_USER}" | cut -d: -f6)"

# run chezmoi
CHEZMOI_ARGS="init --apply --exclude=encrypted"
if [ -n "${CHEZMOI_BRANCH}" ]; then
    CHEZMOI_ARGS="${CHEZMOI_ARGS} --branch ${CHEZMOI_BRANCH}"
fi
CMD="chezmoi ${CHEZMOI_ARGS} ${DOTFILES_REPO}"
sudo --user "${CHEZMOI_USER}" bash -c "cd ${CHEZMOI_USER_HOME} && REMOTE_CONTAINERS=1 ${CMD}"

# Atuin login and sync
# --- Generate a 'pull-git-lfs-artifacts.sh' script to be executed by the 'postCreateCommand' lifecycle hook
INIT_ATUIN_SCRIPT_PATH="/usr/local/share/chezmoi-atuin-init.sh"

tee "$INIT_ATUIN_SCRIPT_PATH" >/dev/null <<EOF
#!/usr/bin/env bash
# (C) Copyright 2025 Christian Kagerer
# Purpose: Initialize Atuin login and sync for chezmoi devcontainer feature

KEEP_GOING="${KEEP_GOING:-false}"

if [[ "\${KEEP_GOING}" == "true" ]]; then
  set +o errexit +o nounset +o pipefail
else
  set -o errexit -o nounset -o pipefail
fi
set -x

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
        ln -s -f /.persist-shell-history/atuin ~/.local/share
    fi

    atuin login --username "\${ATUIN_USER}" --password "\${ATUIN_PASSWORD}" --key "\${ATUIN_KEY}" || true
    atuin sync
fi

if [[ "\${KEEP_GOING}" == "true" ]]; then
  exit 0
fi
EOF

chmod 755 "$INIT_ATUIN_SCRIPT_PATH"

echo "Done"
