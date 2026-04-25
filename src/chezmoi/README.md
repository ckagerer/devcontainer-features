
# Chezmoi (chezmoi)

Install chezmoi and apply dotfiles during the container build.

## Behavior

This feature:

- Installs chezmoi
- runs `chezmoi init --apply --exclude=encrypted` for the configured user during the build
- creates `/usr/local/share/chezmoi-atuin-init.sh` as a `postCreateCommand`

If `atuin_user`, `atuin_password`, and `atuin_key` are set, the post-create hook prepares optional Atuin history persistence and then runs `atuin login` and `atuin sync` when the `atuin` binary is available.

This feature does not install Atuin, Starship, or shell themes. Those tools must come from your dotfiles repository or another feature.

To persist Atuin history across rebuilds, combine this feature with [persist-shell-history](../persist-shell-history/).

If `env_vars` is set, the key-value pairs are exported as environment variables in every shell session (bash and zsh) via the system-wide shell config files.

## Example Usage

```json
"features": {
    "ghcr.io/ckagerer/devcontainer-features/chezmoi:1": {
        "dotfiles_repo": "twpayne/dotfiles"
    }
}
```

## Example With Environment Variables

```json
"features": {
    "ghcr.io/ckagerer/devcontainer-features/chezmoi:1": {
        "dotfiles_repo": "twpayne/dotfiles",
        "env_vars": "MY_VAR=hello;OTHER_VAR=world"
    }
}
```

## Example With Atuin

```json
"features": {
    "ghcr.io/ckagerer/devcontainer-features/chezmoi:1": {
        "dotfiles_repo": "twpayne/dotfiles",
        "atuin_user": "your-user",
        "atuin_password": "your-token",
        "atuin_key": "your-key"
    },
    "ghcr.io/ckagerer/devcontainer-features/persist-shell-history:1": {}
}
```
