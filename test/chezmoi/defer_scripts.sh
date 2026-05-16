#!/bin/bash
# Tests for the defer_scripts=true scenario.
# Verifies that chezmoi files are applied but run_* scripts are deferred to postCreateCommand.

set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

check "post-create script exists and is executable" test -x /usr/local/share/chezmoi-post-create.sh
check "DEFER_SCRIPTS is set to true in post-create script" grep -q 'DEFER_SCRIPTS="true"' /usr/local/share/chezmoi-post-create.sh
check "chezmoi apply --include=scripts is called in post-create script" grep -q 'chezmoi apply --include=scripts' /usr/local/share/chezmoi-post-create.sh
check "EXTRA_ARGS is set in post-create script" grep -q 'EXTRA_ARGS=' /usr/local/share/chezmoi-post-create.sh
# shellcheck disable=SC2016
check "chezmoi source path is initialized (files applied)" sh -c 'source_path=$(chezmoi source-path) && [ -n "$source_path" ] && [ -d "$source_path" ]'

reportResults
