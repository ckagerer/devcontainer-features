#!/bin/bash
set -e

# shellcheck source=/dev/null
source dev-container-features-test-lib

# shellcheck disable=SC2016
check "CHEZMOI_TEST_VAR exported in zsh" zsh -c 'source /etc/zsh/zshenv && [ "${CHEZMOI_TEST_VAR}" = "hello" ]'
# shellcheck disable=SC2016
check "CHEZMOI_OTHER_VAR exported in zsh" zsh -c 'source /etc/zsh/zshenv && [ "${CHEZMOI_OTHER_VAR}" = "world" ]'
# shellcheck disable=SC2016
check "CHEZMOI_SPACE_VAR exported in zsh" zsh -c 'source /etc/zsh/zshenv && [ "${CHEZMOI_SPACE_VAR}" = "hello world" ]'

# Verify chezmoi was successfully initialized while env vars were already available during init
# shellcheck disable=SC2016
check "chezmoi initialized successfully with env_vars set" sh -c 'source_path=$(chezmoi source-path) && [ -n "$source_path" ] && [ -d "$source_path" ]'

reportResults
