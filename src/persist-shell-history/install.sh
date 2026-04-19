#!/usr/bin/env sh
# (C) Copyright 2026 Christian Kagerer
# Purpose: Persist bash and zsh shell history across container rebuilds

set -ex

HISTORY_DIR="/.persist-shell-history"

# Create path for history file that we can mount as a volume
mkdir -p "${HISTORY_DIR}"
chmod 1777 "${HISTORY_DIR}"

# Configuration for bash
if [ -f /etc/bash.bashrc ] && ! grep -q "persist-shell-history" /etc/bash.bashrc; then
  {
    echo ""
    echo "# persist-shell-history"
    echo "export HISTFILE=\"${HISTORY_DIR}/bash_history\""
    echo "export HISTFILESIZE=1000000"
    echo "export HISTSIZE=1000000"
    echo "export PROMPT_COMMAND='history -a'"
  } >>/etc/bash.bashrc
fi

# Configuration for zsh
if [ -d /etc/zsh ] && ! grep -q "persist-shell-history" /etc/zsh/zshenv 2>/dev/null; then
  {
    echo ""
    echo "# persist-shell-history"
    echo "export HISTFILE=\"${HISTORY_DIR}/zsh_history\""
    echo "export HISTSIZE=1000000"
    echo "export SAVEHIST=1000000"
    echo "setopt append_history"
    echo "setopt inc_append_history"
  } >>/etc/zsh/zshenv
fi

echo "Done"
