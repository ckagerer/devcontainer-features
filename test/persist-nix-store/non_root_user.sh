#!/bin/bash
# Tests that /nix/store is owned and writable by the non-root remote user.

set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "/nix/store directory exists" test -d /nix/store
check "/nix/store is writable by the current user" test -w /nix/store
# shellcheck disable=SC2016
check "/nix/store permissions are 755" sh -c '[ "$(stat -c "%a" /nix/store)" = "755" ]'
# shellcheck disable=SC2016
check "/nix/store is owned by the current user" sh -c '[ "$(stat -c "%U" /nix/store)" = "$(id -un)" ]'

reportResults
