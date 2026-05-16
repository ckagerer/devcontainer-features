#!/bin/bash

# This test file will be executed against an auto-generated devcontainer.json that
# includes the 'persist-nix-var' Feature with no options.
#
# For more information, see: https://github.com/devcontainers/cli/blob/main/docs/features/test.md
#
# These scripts are run as 'root' by default. Although that can be changed
# with the '--remote-user' flag.
#
# This test can be run with the following command:
#
#    devcontainer features test    \
#               --features persist-nix-var   \
#               --remote-user root \
#               --skip-scenarios   \
#               --base-image mcr.microsoft.com/devcontainers/base:ubuntu \
#               /path/to/this/repo

set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "/nix/var directory exists" test -d /nix/var
check "/nix/var is writable" test -w /nix/var
# shellcheck disable=SC2016
check "/nix/var permissions are 755" sh -c '[ "$(stat -c "%a" /nix/var)" = "755" ]'
# shellcheck disable=SC2016
check "/nix permissions are 755" sh -c '[ "$(stat -c "%a" /nix)" = "755" ]'

reportResults
