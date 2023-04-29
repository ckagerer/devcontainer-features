#!/bin/bash

# This test file will be executed against an auto-generated devcontainer.json that
# includes the 'persist-shell-history' Feature with no options.
#
# For more information, see: https://github.com/devcontainers/cli/blob/main/docs/features/test.md
#
# Eg:
# {
#    "image": "<..some-base-image...>",
#    "features": {
#      "persist-shell-history": {}
#    },
#    "remoteUser": "root"
# }
#
# Thus, the value of all options will fall back to the default value in the
# Feature's 'devcontainer-feature.json'.
#
# These scripts are run as 'root' by default. Although that can be changed
# with the '--remote-user' flag.
#
# This test can be run with the following command:
#
#    devcontainer features test    \
#               --features persist-shell-history   \
#               --remote-user root \
#               --skip-scenarios   \
#               --base-image mcr.microsoft.com/devcontainers/base:ubuntu \
#               /path/to/this/repo

set -e

# Optional: Import test library bundled with the devcontainer CLI
# See https://github.com/devcontainers/cli/blob/HEAD/docs/features/test.md#dev-container-features-test-lib
# Provides the 'check' and 'reportResults' commands.
source dev-container-features-test-lib

function check_persist_shell_history() {
  if [ -d "/.persist-shell-history" ]; then
    return 0
  else
    echo "Failure: /.persist-shell-history directory does not exist."
    return 1
  fi
}

function test_bash_history() {
  bash -c "printenv" | grep "HISTFILE=/.persist-shell-history/bash_history" || return 1
  return 0
}

function test_zsh_history() {
  zsh -c "printenv" | grep "HISTFILE=/.persist-shell-history/zsh_history" || return 1
  return 0
}

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib. Syntax is...
# check <LABEL> <cmd> [args...]
check "validate if /.persist-shell-history exists" check_persist_shell_history

if [ -x "$(command -v bash)" ]; then
  check "validate if bash HISTFILE variable is set correctly" test_bash_history
fi

if [ -x "$(command -v zsh)" ]; then
  check "validate if zsh HISTFILE variable is set correctly" test_zsh_history
fi

# Report result
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults
