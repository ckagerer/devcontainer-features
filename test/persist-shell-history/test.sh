#!/bin/sh

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

# Direct tests without test library for Alpine compatibility

set -e

echo "Testing persist-shell-history feature..."

# Check if volume mount directory exists
if [ -d "/.persist-shell-history" ]; then
  echo "✓ /.persist-shell-history directory exists"
else
  echo "✗ Failure: /.persist-shell-history directory does not exist"
  exit 1
fi

# Check if /etc/bash.bashrc was configured
if [ -f /etc/bash.bashrc ] && grep -q "HISTFILE.*persist-shell-history" /etc/bash.bashrc; then
  echo "✓ Bash history configuration found in /etc/bash.bashrc"

  # Test bash HISTFILE variable
  if command -v bash >/dev/null 2>&1; then
    histfile=$(bash -c 'echo "$HISTFILE"')
    if [ "$histfile" = "/.persist-shell-history/bash_history" ]; then
      echo "✓ Bash HISTFILE correctly set to /.persist-shell-history/bash_history"
    else
      echo "✗ Bash HISTFILE not set correctly: $histfile"
      exit 1
    fi
  fi
fi

# Check if /etc/zsh/zshenv was configured
if [ -f /etc/zsh/zshenv ] && grep -q "HISTFILE.*persist-shell-history" /etc/zsh/zshenv; then
  echo "✓ Zsh history configuration found in /etc/zsh/zshenv"

  # Test zsh HISTFILE variable
  if command -v zsh >/dev/null 2>&1; then
    histfile=$(zsh -c 'echo "$HISTFILE"')
    if [ "$histfile" = "/.persist-shell-history/zsh_history" ]; then
      echo "✓ Zsh HISTFILE correctly set to /.persist-shell-history/zsh_history"
    else
      echo "✗ Zsh HISTFILE not set correctly: $histfile"
      exit 1
    fi
  fi
fi

echo "✓ All tests passed"
