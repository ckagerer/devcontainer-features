#!/bin/bash
set -e

source dev-container-features-test-lib

check "CHEZMOI_TEST_VAR exported in zsh"  zsh -c 'source /etc/zsh/zshenv && [ "${CHEZMOI_TEST_VAR}" = "hello" ]'
check "CHEZMOI_OTHER_VAR exported in zsh" zsh -c 'source /etc/zsh/zshenv && [ "${CHEZMOI_OTHER_VAR}" = "world" ]'
check "CHEZMOI_SPACE_VAR exported in zsh" zsh -c 'source /etc/zsh/zshenv && [ "${CHEZMOI_SPACE_VAR}" = "hello world" ]'

reportResults
