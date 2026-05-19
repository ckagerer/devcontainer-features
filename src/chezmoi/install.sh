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

# Build a temporary env-export script so ENV_VARS are available during chezmoi init
CHEZMOI_ENV_TMP=""
CHEZMOI_ENV_SOURCE=""
if [ -n "${ENV_VARS:-}" ]; then
  CHEZMOI_ENV_TMP="$(mktemp)"
  chmod 644 "${CHEZMOI_ENV_TMP}"
  printf '%s' "${ENV_VARS}" | tr ';' '\n' | while IFS= read -r pair || [ -n "${pair}" ]; do
    if [ -n "${pair}" ]; then
      key="${pair%%=*}"
      value="${pair#*=}"
      printf 'export %s="%s"\n' "${key}" "${value}" >>"${CHEZMOI_ENV_TMP}"
    fi
  done
  CHEZMOI_ENV_SOURCE=". '${CHEZMOI_ENV_TMP}' && "
fi

# run chezmoi
CHEZMOI_ARGS="init --apply"
if [ -n "${EXTRA_ARGS:-}" ]; then
  CHEZMOI_ARGS="${CHEZMOI_ARGS} ${EXTRA_ARGS}"
fi
if [ -n "${CHEZMOI_BRANCH}" ]; then
  CHEZMOI_ARGS="${CHEZMOI_ARGS} --branch '${CHEZMOI_BRANCH}'"
fi
if [ "${DEFER_SCRIPTS:-false}" = "true" ]; then
  CHEZMOI_ARGS="${CHEZMOI_ARGS} --exclude=scripts"
fi
if [ "${DEBUG:-false}" = "true" ]; then
  CHEZMOI_ARGS="${CHEZMOI_ARGS} --verbose"
fi
CMD="chezmoi ${CHEZMOI_ARGS} '${DOTFILES_REPO}'"

if [ "${DEBUG:-false}" = "true" ]; then
  CHEZMOI_DEBUG_LOG="/var/log/chezmoi-feature-0-build.log"
  printf '=== chezmoi feature debug log: %s ===\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >"${CHEZMOI_DEBUG_LOG}"
  {
    printf '\n-- chezmoi version --\n'
    chezmoi --version 2>&1 || true
    printf '\n-- Feature options --\n'
    printf 'DOTFILES_REPO=%s\n' "${DOTFILES_REPO}"
    printf 'CHEZMOI_BRANCH=%s\n' "${CHEZMOI_BRANCH:-}"
    printf 'CHEZMOI_USER=%s\n' "${CHEZMOI_USER}"
    printf 'CHEZMOI_USER_HOME=%s\n' "${CHEZMOI_USER_HOME}"
    printf 'ENV_VARS=%s\n' "${ENV_VARS:-}"
    printf 'EXTRA_ARGS=%s\n' "${EXTRA_ARGS:-}"
    printf 'KEEP_GOING=%s\n' "${KEEP_GOING:-false}"
    printf '\n-- Resolved chezmoi command --\n'
    printf '%s\n' "cd '${CHEZMOI_USER_HOME}' && ${CHEZMOI_ENV_SOURCE}REMOTE_CONTAINERS=1 ${CMD}"
  } >>"${CHEZMOI_DEBUG_LOG}"
  if [ -n "${CHEZMOI_ENV_TMP}" ] && [ -f "${CHEZMOI_ENV_TMP}" ]; then
    {
      printf '\n-- Injected env file (%s) --\n' "${CHEZMOI_ENV_TMP}"
      cat "${CHEZMOI_ENV_TMP}"
    } >>"${CHEZMOI_DEBUG_LOG}"
  fi
  {
    printf '\n-- Full environment (installer process) --\n'
    env | sort
  } >>"${CHEZMOI_DEBUG_LOG}"
  chmod 640 "${CHEZMOI_DEBUG_LOG}"
  printf 'chezmoi debug log written to %s\n' "${CHEZMOI_DEBUG_LOG}"
fi

CHEZMOI_APPLY_START="$(date +%s)"
CHEZMOI_APPLY_RC=0
sudo --user "${CHEZMOI_USER}" bash -c "cd '${CHEZMOI_USER_HOME}' && ${CHEZMOI_ENV_SOURCE}REMOTE_CONTAINERS=1 ${CMD}" || CHEZMOI_APPLY_RC=$?
CHEZMOI_APPLY_ELAPSED=$(($(date +%s) - CHEZMOI_APPLY_START))

[ -n "${CHEZMOI_ENV_TMP}" ] && rm -f "${CHEZMOI_ENV_TMP}"

if [ "${CHEZMOI_APPLY_RC}" -eq 0 ]; then
  printf '[chezmoi] init --apply: SUCCESS (elapsed=%ds)\n' "${CHEZMOI_APPLY_ELAPSED}"
else
  printf '[chezmoi] init --apply: FAILED exit=%d (elapsed=%ds)\n' "${CHEZMOI_APPLY_RC}" "${CHEZMOI_APPLY_ELAPSED}" >&2
  [ "${KEEP_GOING:-false}" != "true" ] && exit "${CHEZMOI_APPLY_RC}"
fi

if [ "${DEBUG:-false}" = "true" ]; then
  {
    printf '\n-- Post-init: chezmoi status --\n'
    sudo --user "${CHEZMOI_USER}" bash -c "cd '${CHEZMOI_USER_HOME}' && REMOTE_CONTAINERS=1 chezmoi status 2>&1" || true
    printf '\n-- Post-init: chezmoi managed --\n'
    sudo --user "${CHEZMOI_USER}" bash -c "cd '${CHEZMOI_USER_HOME}' && REMOTE_CONTAINERS=1 chezmoi managed 2>&1" || true
    printf '\n-- Post-init: home directory --\n'
    ls -la "${CHEZMOI_USER_HOME}" 2>&1 || true
    printf '\n=== end of debug log ===\n'
  } >>"${CHEZMOI_DEBUG_LOG}"
fi

# --- Generate a script to be executed by the 'postCreateCommand' lifecycle hook.
# Runs deferred chezmoi scripts (when defer_scripts=true) and optional Atuin login/sync.
POST_CREATE_SCRIPT_PATH="/usr/local/share/chezmoi-post-create.sh"

tee "$POST_CREATE_SCRIPT_PATH" >/dev/null <<'EOF'
#!/usr/bin/env bash
# (C) Copyright 2025 Christian Kagerer
# Purpose: Initialize Atuin login and sync for chezmoi devcontainer feature

KEEP_GOING="__KEEP_GOING_PLACEHOLDER__"
DEFER_SCRIPTS="__DEFER_SCRIPTS_PLACEHOLDER__"
EXTRA_ARGS="__EXTRA_ARGS_PLACEHOLDER__"
DEBUG="__DEBUG_PLACEHOLDER__"

if [[ "${KEEP_GOING}" == "true" ]]; then
  set +o errexit +o nounset +o pipefail
else
  set -o errexit -o nounset -o pipefail
fi
set -x

CHEZMOI_POSTCREATE_LOG="/var/log/chezmoi-feature-1-postcreate.log"
if [[ "${DEBUG}" == "true" ]]; then
  printf '=== chezmoi post-create debug log: %s ===\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "${CHEZMOI_POSTCREATE_LOG}"
  {
    printf '\n-- Options --\n'
    printf 'DEFER_SCRIPTS=%s\n' "${DEFER_SCRIPTS}"
    printf 'EXTRA_ARGS=%s\n' "${EXTRA_ARGS}"
    printf 'HOME=%s\n' "${HOME}"
    printf '\n-- Full environment --\n'
    env | sort
  } >> "${CHEZMOI_POSTCREATE_LOG}"
fi

# Run deferred chezmoi scripts (Nix install, home-manager switch, …).
# The /nix named volume is mounted at this point, so the Nix store persists.
if [[ "${DEFER_SCRIPTS}" == "true" ]]; then
  CHEZMOI_SCRIPTS_START="$(date +%s)"
  CHEZMOI_SCRIPTS_RC=0
  if [[ "${DEBUG}" == "true" ]]; then
    printf '\n-- chezmoi apply --include=scripts --\n' >>"${CHEZMOI_POSTCREATE_LOG}"
    # shellcheck disable=SC2086
    chezmoi apply --include=scripts ${EXTRA_ARGS} 2>&1 | tee -a "${CHEZMOI_POSTCREATE_LOG}" || CHEZMOI_SCRIPTS_RC=$?
  else
    # shellcheck disable=SC2086
    chezmoi apply --include=scripts ${EXTRA_ARGS} || CHEZMOI_SCRIPTS_RC=$?
  fi
  CHEZMOI_SCRIPTS_ELAPSED=$(( $(date +%s) - CHEZMOI_SCRIPTS_START ))
  if [[ "${CHEZMOI_SCRIPTS_RC}" -eq 0 ]]; then
    printf '[chezmoi] apply --include=scripts: SUCCESS (elapsed=%ds)\n' "${CHEZMOI_SCRIPTS_ELAPSED}"
  else
    printf '[chezmoi] apply --include=scripts: FAILED exit=%d (elapsed=%ds)\n' "${CHEZMOI_SCRIPTS_RC}" "${CHEZMOI_SCRIPTS_ELAPSED}" >&2
    [[ "${KEEP_GOING}" != "true" ]] && exit "${CHEZMOI_SCRIPTS_RC}"
  fi
fi

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

if [[ "${DEBUG}" == "true" ]]; then
  printf '\n=== end of post-create debug log ===\n' >> "${CHEZMOI_POSTCREATE_LOG}"
fi
EOF

KEEP_GOING_ESCAPED="$(escape_sed_replacement "${KEEP_GOING:-false}")"
DEFER_SCRIPTS_ESCAPED="$(escape_sed_replacement "${DEFER_SCRIPTS:-false}")"
EXTRA_ARGS_ESCAPED="$(escape_sed_replacement "${EXTRA_ARGS:-}")"
DEBUG_ESCAPED="$(escape_sed_replacement "${DEBUG:-false}")"
ATUIN_USER_ESCAPED="$(escape_sed_replacement "${ATUIN_USER:-}")"
ATUIN_PASSWORD_ESCAPED="$(escape_sed_replacement "${ATUIN_PASSWORD:-}")"
ATUIN_KEY_ESCAPED="$(escape_sed_replacement "${ATUIN_KEY:-}")"

sed -i \
  -e "s|__KEEP_GOING_PLACEHOLDER__|${KEEP_GOING_ESCAPED}|g" \
  -e "s|__DEFER_SCRIPTS_PLACEHOLDER__|${DEFER_SCRIPTS_ESCAPED}|g" \
  -e "s|__EXTRA_ARGS_PLACEHOLDER__|${EXTRA_ARGS_ESCAPED}|g" \
  -e "s|__DEBUG_PLACEHOLDER__|${DEBUG_ESCAPED}|g" \
  -e "s|__ATUIN_USER_PLACEHOLDER__|${ATUIN_USER_ESCAPED}|g" \
  -e "s|__ATUIN_PASSWORD_PLACEHOLDER__|${ATUIN_PASSWORD_ESCAPED}|g" \
  -e "s|__ATUIN_KEY_PLACEHOLDER__|${ATUIN_KEY_ESCAPED}|g" \
  "$POST_CREATE_SCRIPT_PATH"

chmod 755 "$POST_CREATE_SCRIPT_PATH"

if [ "${DEBUG:-false}" = "true" ]; then
  touch "/var/log/chezmoi-feature-1-postcreate.log"
  chmod 666 "/var/log/chezmoi-feature-1-postcreate.log"
fi

apply_env_vars() {
  [ -z "${ENV_VARS:-}" ] && return 0

  if [ -f /etc/bash.bashrc ] && ! grep -q "# chezmoi-env-vars" /etc/bash.bashrc; then
    printf "\n# chezmoi-env-vars\n" >>/etc/bash.bashrc
    printf '%s' "${ENV_VARS}" | tr ';' '\n' | while IFS= read -r pair || [ -n "${pair}" ]; do
      if [ -n "${pair}" ]; then
        key="${pair%%=*}"
        value="${pair#*=}"
        printf 'export %s="%s"\n' "${key}" "${value}" >>/etc/bash.bashrc
      fi
    done
  fi

  if [ -d /etc/zsh ] && ! grep -q "# chezmoi-env-vars" /etc/zsh/zshenv 2>/dev/null; then
    printf "\n# chezmoi-env-vars\n" >>/etc/zsh/zshenv
    printf '%s' "${ENV_VARS}" | tr ';' '\n' | while IFS= read -r pair || [ -n "${pair}" ]; do
      if [ -n "${pair}" ]; then
        key="${pair%%=*}"
        value="${pair#*=}"
        printf 'export %s="%s"\n' "${key}" "${value}" >>/etc/zsh/zshenv
      fi
    done
  fi
}

apply_env_vars

echo "Done"
