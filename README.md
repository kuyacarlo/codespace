# codespace

Minimal Debian-based development container for internal development tooling, optimized for rootless Podman and Docker.

## Included

- zsh + oh-my-zsh (robbyrussell theme)
- uv (Python toolchain)
- pnpm (Node package manager)
- gvm (Go Version Manager)
- PostgreSQL 17 (client + server packages)
- gh CLI
- act (GitHub Actions local runner)
- Docker CLI (for act runtime)
- Build essentials: gcc, g++, make, cmake, ninja-build, pkg-config, python3, python3-dev

## Design & Optimization

- **Base Distribution**: Debian Bookworm (`debian:bookworm-slim`).
- **Parallel Downloads**: Leverages a multi-stage Docker build (`downloader` stage) to download external binaries (`gh`, `act`, `docker`, `buildx`, `uv`) in parallel.
- **Fast Rebuilds**: Uses BuildKit cache mounts (`--mount=type=cache`) for `apt-get` directories, speeding up package install steps to under 15 seconds.
- **Rootless Compatibility**:
  - Automatically disables the APT privilege-dropping sandbox to prevent permission failures.
  - Implements temporary shadow mocks (`su`, `install`, `chown`, `chgrp`, `dpkg-statoverride`) during package config to bypass rootless user namespace restrictions (especially for `postgresql-common`).
  - Disables automatic cluster creation during package build time (`create_main_cluster = false`), deferring database initialization to runtime.
  - Defaults the container run user to `root` (which maps directly to your host UID/GID in single-UID environments), while still installing all tools (Oh-My-Zsh, GVM) for both the `root` and `vscode` home directories.

## Configuration & Overrides

- `act` is configured from repository `.actrc` via `.devcontainer/postCreate.sh`.
- Add local overrides by copying `.actrc.override.example` to `.actrc.override`.

## Usage

1. Open this repository in VS Code / Codespaces (rebuilding the container under Podman or Docker).
2. The post-create hook runs automatically to validate all installed tool versions.

## Verification Checks

Run these in the container terminal to verify all toolchains:

```bash
zsh --version
uv --version
pnpm --version
act --version
gh --version
psql --version
postgres --version
```