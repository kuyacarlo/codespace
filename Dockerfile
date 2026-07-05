FROM docker.io/library/debian:bookworm-slim AS downloader

ARG GH_VERSION=2.55.0
ARG ACT_VERSION=0.2.89
ARG DOCKER_CLI_VERSION=27.3.1
ARG UV_VERSION=0.5.20
ARG PNPM_VERSION=9.12.2
ARG BUILDX_VERSION=0.19.3
ARG TARGETARCH

RUN echo 'APT::Sandbox::User "root";' > /etc/apt/apt.conf.d/01-sandbox-disable && \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl tar unzip xz-utils wget gnupg

# Download and install gh (GitHub CLI)
RUN set -eux; \
    curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_$(dpkg --print-architecture).tar.gz" -o /tmp/gh.tgz; \
    tar --no-same-owner -xzf /tmp/gh.tgz -C /tmp; \
    mv /tmp/gh_${GH_VERSION}_linux_$(dpkg --print-architecture)/bin/gh /usr/bin/gh; \
    chmod +x /usr/bin/gh; \
    rm -rf /tmp/gh.tgz /tmp/gh_${GH_VERSION}_linux_$(dpkg --print-architecture)

# Download and install docker CLI + buildx plugin (arch-aware, was previously missing entirely)
RUN set -eux; \
    curl -fsSL "https://download.docker.com/linux/static/stable/$(dpkg --print-architecture | sed 's/amd64/x86_64/;s/arm64/aarch64/')/docker-${DOCKER_CLI_VERSION}.tgz" -o /tmp/docker.tgz; \
    tar --no-same-owner -xzf /tmp/docker.tgz -C /tmp; \
    mv /tmp/docker/docker /usr/local/bin/docker; \
    chmod +x /usr/local/bin/docker; \
    rm -rf /tmp/docker /tmp/docker.tgz; \
    mkdir -p /usr/local/lib/docker/cli-plugins; \
    curl -fsSL "https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-$(dpkg --print-architecture)" \
      -o /usr/local/lib/docker/cli-plugins/docker-buildx; \
    chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

# Download and install act (nektos/act — the runner), was previously missing entirely
RUN set -eux; \
    curl -fsSL "https://github.com/nektos/act/releases/download/v${ACT_VERSION}/act_Linux_$(dpkg --print-architecture | sed 's/amd64/x86_64/;s/arm64/arm64/').tar.gz" -o /tmp/act.tgz; \
    tar --no-same-owner -xzf /tmp/act.tgz -C /usr/local/bin act; \
    chmod +x /usr/local/bin/act; \
    rm -f /tmp/act.tgz

# Download uv
RUN curl -fsSL https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin UV_UNMANAGED_INSTALL=/usr/local/bin UV_VERSION=${UV_VERSION} sh

# Install prek - faster pre-commit alternative
RUN curl --proto '=https' --tlsv1.2 -LsSf https://github.com/j178/prek/releases/latest/download/prek-installer.sh | PREK_NO_MODIFY_PATH=1 sh && \
    mv /root/.local/bin/prek /usr/local/bin/prek 2>/dev/null || mv prek /usr/local/bin/prek && \
    chmod +x /usr/local/bin/prek

# Symlink for pre-commit compatibility
RUN ln -sf /usr/local/bin/prek /usr/local/bin/pre-commit

# ---------------------------------------------------------------------------
# Main Stage
# ---------------------------------------------------------------------------
FROM docker.io/library/debian:bookworm-slim

ARG PNPM_VERSION=9.12.2

# Set default locale environment variables
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8


# Disable APT sandbox to prevent seteuid/setgroups permission issues under rootless Podman
RUN echo 'APT::Sandbox::User "root";' > /etc/apt/apt.conf.d/01-sandbox-disable

# Prevent postgresql-common from creating a default database cluster during build
RUN mkdir -p /etc/postgresql-common && \
    echo "create_main_cluster = false" > /etc/postgresql-common/createcluster.conf

# Add official PostgreSQL repository for PostgreSQL 17
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg2 wget && \
    install -d /etc/apt/keyrings && \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/keyrings/postgresql.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list

# Install base packages
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=bind,source=scripts/setup-build-wrappers.sh,target=/tmp/setup-build-wrappers.sh \
    /tmp/setup-build-wrappers.sh && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        acl \
        bash \
        bison \
        bsdextrautils \
        build-essential \
        cmake \
        git \
        git-lfs \
        gzip \
        locales \
        make \
        ninja-build \
        nodejs \
        npm \
        openssh-client \
        patch \
        pkg-config \
        postgresql-17 \
        postgresql-contrib-17 \
        procps \
        python3 \
        python3-dev \
        python3-pip \
        python3-venv \
        sudo \
        tar \
        unzip \
        xz-utils \
        zsh && \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen && \
    rm -rf /var/lib/apt/lists/*

# Install essential Python packages (keep minimal for language-agnostic approach)
RUN pip3 install --no-cache-dir --break-system-packages \
    pre-commit \
    black \
    isort \
    ruff \
    pytest \
    ipython \
    python-dotenv \
    rich

# Symlink PostgreSQL server binaries to /usr/bin for compatibility
RUN ln -sf /usr/lib/postgresql/17/bin/postgres /usr/bin/postgres && \
    ln -sf /usr/lib/postgresql/17/bin/initdb /usr/bin/initdb && \
    ln -sf /usr/lib/postgresql/17/bin/pg_ctl /usr/bin/pg_ctl

# Create vscode user
RUN groupadd --gid 1000 vscode && \
    useradd --uid 1000 --gid 1000 --shell /usr/bin/zsh --create-home vscode && \
    echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode && \
    chmod 0440 /etc/sudoers.d/vscode

# Copy your generic scripts (make sure these exist in your repo)
COPY --chown=root:root ./etc /etc
COPY --chown=root:root ./opt /opt

# Make scripts executable
RUN chmod a+rx /opt/bin/* 2>/dev/null || true && \
    chmod a+rx /etc/profile.d/*.sh 2>/dev/null || true

# Copy pre-downloaded binaries from downloader stage
COPY --from=downloader /usr/bin/gh /usr/bin/gh
COPY --from=downloader /usr/local/bin/act /usr/local/bin/act
COPY --from=downloader /usr/local/bin/docker /usr/local/bin/docker
COPY --from=downloader /usr/local/lib/docker/cli-plugins/docker-buildx /usr/local/lib/docker/cli-plugins/docker-buildx
COPY --from=downloader /usr/local/bin/uv /usr/local/bin/uv
COPY --from=downloader /usr/local/bin/prek /usr/local/bin/prek
COPY --from=downloader /usr/local/bin/pre-commit /usr/local/bin/pre-commit

# Install pnpm globally
RUN npm install --global pnpm@${PNPM_VERSION}

# Setup shell environment for vscode user
RUN HOME=/home/vscode RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
    HOME=/home/vscode bash -lc "curl -fsSL https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer | bash" && \
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="robbyrussell"/' /home/vscode/.zshrc && \
    grep -Fq 'bindkey "^[[1;5D" backward-word' /home/vscode/.zshrc || printf '\n# Ctrl+Arrow word navigation in VS Code terminal\nbindkey "^[[1;5D" backward-word\nbindkey "^[[1;5C" forward-word\nbindkey "^[[5D" backward-word\nbindkey "^[[5C" forward-word\n' >> /home/vscode/.zshrc && \
    grep -Fq '[[ -s "$HOME/.gvm/scripts/gvm" ]] && . "$HOME/.gvm/scripts/gvm"' /home/vscode/.zshrc || printf '\n# gvm\n[[ -s "$HOME/.gvm/scripts/gvm" ]] && . "$HOME/.gvm/scripts/gvm"\n' >> /home/vscode/.zshrc && \
    grep -Fq 'eval "$(uv generate-shell-completion zsh)"' /home/vscode/.zshrc || printf '\n# UV completion\neval "$(uv generate-shell-completion zsh)"\n' >> /home/vscode/.zshrc && \
    grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' /home/vscode/.zshrc || printf '\n# Python environment\nexport PATH="$HOME/.local/bin:$PATH"\nexport PYTHONUNBUFFERED=1\n' >> /home/vscode/.zshrc && \
    grep -Fq 'load-venv()' /home/vscode/.zshrc || printf '\n# Auto-activate venv\nload-venv() {\n  if [[ -f "./.venv/bin/activate" ]]; then\n    source ./.venv/bin/activate\n  fi\n}\nautoload -U add-zsh-hook\nadd-zsh-hook chpwd load-venv\nload-venv\n' >> /home/vscode/.zshrc && \
    grep -Fq 'alias python=' /home/vscode/.zshrc || printf '\n# Aliases\nalias python=python3\nalias pip="uv pip"\n' >> /home/vscode/.zshrc && \
    grep -Fq '[[ -f /etc/motd ]] && cat /etc/motd' /home/vscode/.zshrc || printf '\n[[ -f /etc/motd ]] && cat /etc/motd\n' >> /home/vscode/.zshrc && \
    (chown -R vscode:vscode /home/vscode || true) && \
    chmod -R 755 /home/vscode

# Setup shell environment for root
RUN HOME=/root RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
    HOME=/root bash -lc "curl -fsSL https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer | bash" && \
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="robbyrussell"/' /root/.zshrc && \
    grep -Fq 'bindkey "^[[1;5D" backward-word' /root/.zshrc || printf '\n# Ctrl+Arrow word navigation in VS Code terminal\nbindkey "^[[1;5D" backward-word\nbindkey "^[[1;5C" forward-word\nbindkey "^[[5D" backward-word\nbindkey "^[[5C" forward-word\n' >> /root/.zshrc && \
    grep -Fq '[[ -s "$HOME/.gvm/scripts/gvm" ]] && . "$HOME/.gvm/scripts/gvm"' /root/.zshrc || printf '\n# gvm\n[[ -s "$HOME/.gvm/scripts/gvm" ]] && . "$HOME/.gvm/scripts/gvm"\n' >> /root/.zshrc && \
    grep -Fq 'eval "$(uv generate-shell-completion zsh)"' /root/.zshrc || printf '\n# UV completion\neval "$(uv generate-shell-completion zsh)"\n' >> /root/.zshrc && \
    grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' /root/.zshrc || printf '\n# Python environment\nexport PATH="$HOME/.local/bin:$PATH"\nexport PYTHONUNBUFFERED=1\n' >> /root/.zshrc && \
    grep -Fq 'load-venv()' /root/.zshrc || printf '\n# Auto-activate venv\nload-venv() {\n  if [[ -f "./.venv/bin/activate" ]]; then\n    source ./.venv/bin/activate\n  fi\n}\nautoload -U add-zsh-hook\nadd-zsh-hook chpwd load-venv\nload-venv\n' >> /root/.zshrc && \
    grep -Fq 'alias python=' /root/.zshrc || printf '\n# Aliases\nalias python=python3\nalias pip="uv pip"\n' >> /root/.zshrc && \
    grep -Fq '[[ -f /etc/motd ]] && cat /etc/motd' /root/.zshrc || printf '\n[[ -f /etc/motd ]] && cat /etc/motd\n' >> /root/.zshrc

# Create default pre-commit configuration (language-agnostic)
# Create default pre-commit configuration (language-agnostic)
RUN printf '%s\n' \
    'repos:' \
    '  - repo: local' \
    '    hooks:' \
    '      - id: trailing-whitespace' \
    '        name: trailing-whitespace' \
    '        entry: trailing-whitespace-fixer' \
    '        language: system' \
    '        types: [text]' \
    '      - id: end-of-file-fixer' \
    '        name: end-of-file-fixer' \
    '        entry: end-of-file-fixer' \
    '        language: system' \
    '        types: [text]' \
    > /home/vscode/.pre-commit-config.yaml

RUN (chown vscode:vscode /home/vscode/.pre-commit-config.yaml || true) && \
    chmod 644 /home/vscode/.pre-commit-config.yaml

# Create workspaces directory
RUN mkdir -p /workspaces/codespace && (chown -R vscode:vscode /workspaces || true) && chmod -R 775 /workspaces

# Set working directory
WORKDIR /workspaces/codespace

# Switch to vscode user
USER vscode
