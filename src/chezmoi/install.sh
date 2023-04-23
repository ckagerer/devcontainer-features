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
if ! command -v curl &> /dev/null; then
    apt install -y curl
fi

# check if sudo is installed
if ! command -v sudo &> /dev/null; then
    apt install -y sudo
fi

# check if git is installed
if ! command -v git &> /dev/null; then
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
CMD="chezmoi ${CHEZMOI_ARGS[*]} ${DOTFILES_REPO}"
sudo --user "${CHEZMOI_USER}" bash -c "cd ${CHEZMOI_USER_HOME} && REMOTE_CONTAINERS=1 ${CMD}"

echo "Done"
