# Dev Container Features

A collection of small Dev Container Features—each in `src/<feature>`—providing reusable units that compose into devcontainer builds.

## 1. Project Overview

### What this project does

This repository contains a set of Dev Container Features (reusable units) that install tools and configuration into development containers. Each feature lives under `src/<feature>` and exposes a `devcontainer-feature.json` and an `install.sh` entrypoint. Features are designed to run inside container images used by VS Code Remote - Containers and devcontainer tooling.

### Primary languages and build system

- **Primary languages**: Shell scripts (POSIX/sh, Bash) and JSON for feature metadata. Minor documentation in Markdown.
- **Build/toolchain**: No compiled build system. Tools used during development: `bash`, `sh`, `wget`, `curl`, `apt`/`apk` package managers, `npm` for developer tooling, and Git for versioning.
- **Development image**: Node image `mcr.microsoft.com/devcontainers/javascript-node:1-18` with `@devcontainers/cli` installed in `postCreateCommand`.

### Target platform

- **Runtime**: Linux containers (Debian/Ubuntu and Alpine supported)
- **Use case**: VS Code Remote - Containers / devcontainer integration

## 2. Directory Structure

```
project-root/
├── src/                        # Feature implementations
│   ├── chezmoi/                # Feature: installs chezmoi dotfile manager
│   │   ├── devcontainer-feature.json
│   │   ├── install.sh
│   │   └── README.md
│   ├── clang/                  # Feature: installs clang/llvm toolchain
│   │   ├── devcontainer-feature.json
│   │   ├── install.sh
│   │   └── README.md
│   └── persist-shell-history/  # Feature: persists shell history across containers
│       ├── devcontainer-feature.json
│       ├── install.sh
│       └── README.md
├── test/                       # Feature tests and test scenarios
│   ├── chezmoi/
│   │   ├── scenarios.json
│   │   └── test.sh
│   ├── clang/
│   │   ├── scenarios.json
│   │   └── test.sh
│   └── persist-shell-history/
│       ├── scenarios.json
│       └── test.sh
├── .devcontainer.json          # VS Code devcontainer config for local development
├── README.md                   # Project documentation
├── LICENSE                     # License file
└── AGENTS.md                   # This file: guidance for AI coding agents
```

### Adding new features

1. Create `src/<feature-name>/` directory using kebab-case
2. Add minimum files:
   - `devcontainer-feature.json`: Metadata for the feature
   - `install.sh`: Installer entrypoint
   - `README.md`: Documentation of options and behavior
3. Add test files under `test/<feature-name>/`:
   - `scenarios.json`: Test scenarios configuration
   - `test.sh`: Test script

## 3. Key Conventions

### Code style

- **Shell variant**: Prefer POSIX `sh` compatibility; use `bash` for features requiring bash-specific constructs (arrays, etc.)
- **Shebangs**: Use `#!/usr/bin/env sh` or `#!/usr/bin/env bash`; follow existing style in the feature folder
- **Set options**: Use `set -e` (exit on error), `set -u` (fail on undefined vars), `set -o pipefail` (fail on pipe errors). Some features provide `KEEP_GOING` flags to skip strict failure behavior
- **Logging**: Use `set -x` for debug traces in installers; keep output well-structured; use `echo` for user messages
- **Idempotence**: Installers must be safe to run multiple times; check for existing commands before installing packages
- **Indentation**: Maintain consistent indentation (2 or 4 spaces) and clear function separation

### Naming conventions

- **Feature directories**: kebab-case (e.g., `persist-shell-history`)
- **Executables/scripts**: `install.sh` is the standard entrypoint per feature
- **JSON metadata**: `devcontainer-feature.json` must include:
  - `name`: Human-readable feature name
  - `id`: Unique identifier (usually kebab-case)
  - `version`: Semantic versioning (e.g., `1.6.1`)
  - `description`: Brief description
  - `documentationURL`: Link to feature documentation
  - Optional: `options`, `mounts`, `installsAfter`, `postCreateCommand`

### File organization

- **Feature files**: Implementation scripts and helpers live in `src/<feature>/`
- **Tests**: Integration tests placed in `test/<feature>/` with `scenarios.json` and `test.sh` pattern
- **Configuration**:
  - `.devcontainer.json`: VS Code devcontainer configuration
  - `devcontainer-feature.json`: Feature metadata consumed by devcontainer tooling
  - Feature `README.md`: Documents options, environment variables, and any special setup

## 4. Architecture Patterns

- **Independence**: Each feature is self-contained; `devcontainer-feature.json` defines metadata and options, `install.sh` performs installation
- **Ordering**: Features declare `installsAfter` in JSON to express build order constraints
- **Error handling**: Default behavior uses `set -e` to abort on errors. Features may provide `KEEP_GOING` option to continue on failure
- **Idempotency**: Installers check for presence of tools before reinstalling; safe to run multiple times
- **Distribution abstraction**: Detect OS via `/etc/debian_version` (Debian/Ubuntu) or `/etc/alpine-release` (Alpine); choose package manager (`apt` vs `apk`) accordingly. Keep distro detection centralized in `install.sh`
- **Build-time execution**: Scripts run sequentially during container build; avoid backgrounding tasks that affect determinism

## 5. Build System

No compiled build system. Development and testing commands:

```bash
# Inside devcontainer: Install dev tooling
npm install -g @devcontainers/cli

# Run a feature installer locally (for testing)
bash src/<feature>/install.sh

# Run linter on shell scripts
shellcheck src/clang/install.sh

# Run bats tests (if present)
bats test/foo.bats
```

### Environment variables and options

Features read options from environment variables mapped to `devcontainer-feature.json` options:
- Example: `DOTFILES_REPO`, `CHEZMOI_BRANCH`, `KEEP_GOING`, `ATUIN_*`
- Document all expected environment variables in feature `README.md`

## 6. Development Workflow

### Adding new features

1. Create `src/<feature-name>/` directory (kebab-case)
2. Add `devcontainer-feature.json` with schema fields: `name`, `id`, `version` (semver), `description`, `documentationURL`, optional `options`, `installsAfter`, `mounts`
3. Add `install.sh` as installer entrypoint; make executable; follow distro detection, package checks, and idempotence patterns from existing features
4. Add `README.md` documenting:
   - What the feature does
   - All options (mapped to environment variables)
   - Environment variables required/supported
   - Any host setup requirements
5. Add tests under `test/<feature>/` if behavior should be validated automatically
6. Follow shell style rules from [shell-script-user.instructions.md](vscode-userdata:/home/ckagerer/.config/Code/User/prompts/shell-script-user.instructions.md)

### Testing

- **Static analysis**: Use `shellcheck` for shell script validation
- **Integration tests**: Use `bats` (Bash Automated Testing System) or custom shell test harness
- **Test runners**: Provide `test/run.sh` wrapper if adding comprehensive tests

## 7. Important Context

### What AI agents should know

**Critical files**:
- `devcontainer-feature.json` files under `src/*/`: Control feature metadata and build ordering
- `install.sh` scripts: Critical runtime entrypoints executed during container build
- `.devcontainer.json`: Affects local development image and installed dev tools

**Protected files** (do not change without approval):
- Files under `.github/` (CI workflows)
- `.devcontainer.json`
- `LICENSE`
- Do not edit `devcontainer-feature.json` version fields lightly—maintain semantic versioning

**Performance-sensitive areas**:
- Network operations in `install.sh` (large downloads): Keep retries and timeouts consistent
- Avoid heavy CPU work in installer scripts

**API/ABI compatibility**:
- Features expose behavior via container side-effects, mounts, and `postCreateCommand`
- Keep option names stable; bump `version` on breaking changes

**Platform-specific code**:
- All installers must contain distro detection
- If adding code for a new platform, place it inside `install.sh` and document preconditions in `README.md`

### What to avoid

**Anti-patterns**:
- Hardcoding home directory paths; use `getent` or environment variables (see `CHEZMOI_USER_HOME` usage in `src/chezmoi/install.sh`)
- Assuming a single package manager; use distro detection and install guards
- Modifying `.github/` workflows or `.devcontainer.json` without tests and approval

**Deprecated patterns**:
- Avoid full `set -e` without cleanup for generated files if `KEEP_GOING` semantics are expected

**Files never to edit manually**:
- Any file documented as generated
- CI workflow files in `.github/` (unless explicitly updating CI)

## 8. Code Examples

### Typical `devcontainer-feature.json`

```json
{
  "name": "chezmoi",
  "id": "chezmoi",
  "version": "1.6.1",
  "description": "Install chezmoi dotfile manager",
  "documentationURL": "https://github.com/ckagerer/devcontainer-features/tree/main/src/chezmoi",
  "options": {
    "version": {
      "type": "string",
      "default": "latest",
      "description": "Version of chezmoi to install"
    }
  },
  "postCreateCommand": "/usr/local/share/chezmoi-init.sh"
}
```

### Typical `install.sh` pattern

```sh
#!/usr/bin/env sh

if [ "${KEEP_GOING:-false}" = "true" ]; then
  set +e
else
  set -e
fi
set -x

# Validate required environment variables
if [ -z "${DOTFILES_REPO}" ]; then
  echo "DOTFILES_REPO is not set"
  exit 1
fi

# Distribution detection
if [ -f /etc/debian_version ]; then
  apt update
  apt install -y curl
elif [ -f /etc/alpine-release ]; then
  apk add --no-cache curl
else
  echo "Unsupported distribution"
  exit 1
fi

# Check if already installed
if command -v chezmoi >/dev/null 2>&1; then
  echo "chezmoi already installed"
  exit 0
fi

# Install
curl -fsSL https://get.chezmoi.io | sh
```

## 9. References

- **Project documentation**: [README.md](README.md) (project root) and each feature's `README.md` under [src/](src/)
- **Devcontainer features specification**: https://containers.dev/implementors/features/
- **Coding conventions**:
  - Shell scripts: [shell-script-user.instructions.md](vscode-userdata:/home/ckagerer/.config/Code/User/prompts/shell-script-user.instructions.md)
  - Markdown: [markdown.instructions.md](vscode-userdata:/home/ckagerer/.config/Code/User/prompts/markdown.instructions.md)

## Prescriptive Agent Rules (must follow)

1. **Make minimal edits**: Prefer small, well-tested changes and preserve existing code style
2. **Never edit generated or protected files** (see section 7); update generator/config instead
3. **Always add or update tests** for behavior changes; include test command in commit message if relevant
4. **Run linters and tests locally** (or in devcontainer) before proposing changes
5. **Merge, don't replace**: If modifying AGENTS.md, preserve existing useful sections
6. **Document changes**: Note cross-cutting changes in AGENTS.md and link affected files
7. **Ask before large changes**: If uncertain about file placement or testing strategy, ask before making sweeping modifications
