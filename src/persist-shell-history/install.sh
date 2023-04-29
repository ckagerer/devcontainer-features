#!/usr/bin/env bash

set -ex

HISTORY_DIR="/.persist-shell-history"

# Create path for history file that we can mount as a volume
mkdir -p $HISTORY_DIR
chmod 777 $HISTORY_DIR

# Configuration for bash
if [ -f /etc/bash.bashrc ]; then
{
    echo "export HISTFILE=\"$HISTORY_DIR/bash_history\""
    echo "export HISTFILESIZE=1000000"
    echo "export HISTSIZE=1000000"
    echo "export PROMPT_COMMAND='history -a'"
} >> /etc/bash.bashrc
fi

# Configuration for zsh
if [ -f /etc/zsh/zshrc ]; then
{
    echo "export HISTFILE=\"$HISTORY_DIR/zsh_history\""
    echo "export HISTFILESIZE=1000000"
    echo "export HISTSIZE=1000000"
    echo "setopt append_history"
    echo "setopt inc_append_history"
} >> /etc/zsh/zshenv
fi

echo "Done"
