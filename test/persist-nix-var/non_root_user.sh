#!/bin/bash
# Tests that /nix/var is owned and writable by the non-root remote user.

set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "/nix/var directory exists" test -d /nix/var
check "/nix/var is writable by the current user" test -w /nix/var
# shellcheck disable=SC2016
check "/nix/var permissions are 755" sh -c '[ "$(stat -c "%a" /nix/var)" = "755" ]'
# shellcheck disable=SC2016
check "/nix/var is owned by the current user" sh -c '[ "$(stat -c "%U" /nix/var)" = "$(id -un)" ]'
# shellcheck disable=SC2016
check "/nix is owned by the current user" sh -c '[ "$(stat -c "%U" /nix)" = "$(id -un)" ]'

reportResults
