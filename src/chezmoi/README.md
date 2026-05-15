
# Chezmoi (chezmoi)

Install chezmoi and apply dotfiles during the container build.

## Behavior

This feature:

- Installs chezmoi
- Runs `chezmoi init --apply --exclude=encrypted` for the configured user during the build
- Creates `/usr/local/share/chezmoi-post-create.sh` as a `postCreateCommand`

If `atuin_user`, `atuin_password`, and `atuin_key` are set, the post-create hook prepares optional
Atuin history persistence and then runs `atuin login` and `atuin sync` when the `atuin` binary is
available.

This feature does not install Atuin, Starship, or shell themes. Those tools must come from your
dotfiles repository or another feature.

To persist Atuin history across rebuilds, combine this feature with
[persist-shell-history](../persist-shell-history/).

If `env_vars` is set, the key-value pairs are exported as environment variables in every shell
session (bash and zsh) via the system-wide shell config files.

## Deferring Scripts (Nix / slow installs)

By default, chezmoi `run_*` scripts execute at **build time**. If your dotfiles install Nix and run
`home-manager switch`, every rebuild downloads the full package set — which can take 30+ minutes on
a slow connection.

Set `defer_scripts: true` to skip `run_*` scripts during the build and run them in
`postCreateCommand` instead. Combine this with the
[persist-nix-store](../persist-nix-store/) feature, which mounts a named Docker volume at
`/nix/store`. Because volumes are available at post-create time (not build time), the Nix store
accumulates across rebuilds: only changed packages are downloaded on subsequent builds.

When `defer_scripts` is `false` (the default), behaviour is identical to previous versions of this
feature.

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

## Example With Nix Store Caching

```json
"features": {
    "ghcr.io/ckagerer/devcontainer-features/chezmoi:1": {
        "dotfiles_repo": "your-user/dotfiles",
        "defer_scripts": true
    },
    "ghcr.io/ckagerer/devcontainer-features/persist-nix-store:1": {}
}
```

The `devcontainer-nix-store` volume is shared across all projects, so packages downloaded for one
devcontainer are immediately available to others.

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
