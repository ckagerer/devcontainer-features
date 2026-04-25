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

escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[\\&|]/\\&/g'
}

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
curl --fail --silent --location --show-error --retry 10 --output "$INSTALLER_PATH" https://get.chezmoi.io
chmod +x "$INSTALLER_PATH"
BINDIR="/usr/local/bin" "$INSTALLER_PATH"
rm "$INSTALLER_PATH"

# get home directory of user ${CHEZMOI_USER}
CHEZMOI_USER_HOME="$(getent passwd "${CHEZMOI_USER}" | cut -d: -f6)"

# run chezmoi
CHEZMOI_ARGS="init --apply --exclude=encrypted"
if [ -n "${CHEZMOI_BRANCH}" ]; then
  CHEZMOI_ARGS="${CHEZMOI_ARGS} --branch '${CHEZMOI_BRANCH}'"
fi
CMD="chezmoi ${CHEZMOI_ARGS} '${DOTFILES_REPO}'"
sudo --user "${CHEZMOI_USER}" bash -c "cd '${CHEZMOI_USER_HOME}' && REMOTE_CONTAINERS=1 ${CMD}"

# Atuin login and sync
# --- Generate a 'pull-git-lfs-artifacts.sh' script to be executed by the 'postCreateCommand' lifecycle hook
INIT_ATUIN_SCRIPT_PATH="/usr/local/share/chezmoi-atuin-init.sh"

tee "$INIT_ATUIN_SCRIPT_PATH" >/dev/null <<'EOF'
#!/usr/bin/env bash
# (C) Copyright 2025 Christian Kagerer
# Purpose: Initialize Atuin login and sync for chezmoi devcontainer feature

KEEP_GOING="__KEEP_GOING_PLACEHOLDER__"

if [[ "${KEEP_GOING}" == "true" ]]; then
  set +o errexit +o nounset +o pipefail
else
  set -o errexit -o nounset -o pipefail
fi
set -x

ATUIN_USER="__ATUIN_USER_PLACEHOLDER__"
ATUIN_PASSWORD="__ATUIN_PASSWORD_PLACEHOLDER__"
ATUIN_KEY="__ATUIN_KEY_PLACEHOLDER__"

if [[ -z "${ATUIN_USER}" || -z "${ATUIN_PASSWORD}" || -z "${ATUIN_KEY}" ]]; then
  echo "Atuin credentials not configured; skipping atuin initialization"
  exit 0
fi

# If /.persist-shell-history exists, we assume that the user wants to persist also the atuin history.
if [[ -d "/.persist-shell-history" ]]; then
  if [[ -d "${HOME}/.local/share/atuin" && ! -L "${HOME}/.local/share/atuin" ]]; then
    mv "${HOME}/.local/share/atuin" "${HOME}/.local/share/atuin.bak"
  fi

  mkdir -p "/.persist-shell-history/atuin"
  mkdir -p "${HOME}/.local/share"
  ln -sfn "/.persist-shell-history/atuin" "${HOME}/.local/share/atuin"
fi

if ! command -v atuin >/dev/null 2>&1; then
  echo "Atuin credentials are configured, but atuin is not installed. Skipping login and sync." >&2
  exit 0
fi

atuin login --username "${ATUIN_USER}" --password "${ATUIN_PASSWORD}" --key "${ATUIN_KEY}" || true
atuin sync

if [[ "${KEEP_GOING}" == "true" ]]; then
  exit 0
fi
EOF

KEEP_GOING_ESCAPED="$(escape_sed_replacement "${KEEP_GOING:-false}")"
ATUIN_USER_ESCAPED="$(escape_sed_replacement "${ATUIN_USER:-}")"
ATUIN_PASSWORD_ESCAPED="$(escape_sed_replacement "${ATUIN_PASSWORD:-}")"
ATUIN_KEY_ESCAPED="$(escape_sed_replacement "${ATUIN_KEY:-}")"

sed -i \
  -e "s|__KEEP_GOING_PLACEHOLDER__|${KEEP_GOING_ESCAPED}|g" \
  -e "s|__ATUIN_USER_PLACEHOLDER__|${ATUIN_USER_ESCAPED}|g" \
  -e "s|__ATUIN_PASSWORD_PLACEHOLDER__|${ATUIN_PASSWORD_ESCAPED}|g" \
  -e "s|__ATUIN_KEY_PLACEHOLDER__|${ATUIN_KEY_ESCAPED}|g" \
  "$INIT_ATUIN_SCRIPT_PATH"

chmod 755 "$INIT_ATUIN_SCRIPT_PATH"

apply_env_vars() {
  [ -z "${ENV_VARS:-}" ] && return 0

  if [ -f /etc/bash.bashrc ] && ! grep -q "# chezmoi-env-vars" /etc/bash.bashrc; then
    printf "\n# chezmoi-env-vars\n" >>/etc/bash.bashrc
    printf '%s' "${ENV_VARS}" | tr ';' '\n' | while IFS= read -r pair || [ -n "${pair}" ]; do
      [ -n "${pair}" ] && printf 'export %s\n' "${pair}" >>/etc/bash.bashrc
    done
  fi

  if [ -d /etc/zsh ] && ! grep -q "# chezmoi-env-vars" /etc/zsh/zshenv 2>/dev/null; then
    printf "\n# chezmoi-env-vars\n" >>/etc/zsh/zshenv
    printf '%s' "${ENV_VARS}" | tr ';' '\n' | while IFS= read -r pair || [ -n "${pair}" ]; do
      [ -n "${pair}" ] && printf 'export %s\n' "${pair}" >>/etc/zsh/zshenv
    done
  fi
}

apply_env_vars

echo "Done"
