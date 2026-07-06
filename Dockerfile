FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# --------------------------------------------------
# Base system
# --------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget gnupg git git-lfs \
    bash zsh sudo neovim \
    build-essential make cmake \
    locales unzip xz-utils tar procps \
    python3 python3-pip python3-venv python3-dev \
    python3-isort python3-pytest ipython3 python3-dotenv \
    nodejs npm \
    postgresql postgresql-contrib \
    && rm -rf /var/lib/apt/lists/*

RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8

# --------------------------------------------------
# user
# --------------------------------------------------
RUN groupadd -g 1000 vscode && \
    useradd -m -u 1000 -g 1000 -s /bin/zsh vscode && \
    echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode

# --------------------------------------------------
# tools (cached layers)
# --------------------------------------------------

ARG GH_VERSION=2.55.0

RUN arch="$(dpkg --print-architecture)" && \
    curl -fsSL \
    "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${arch}.tar.gz" \
    -o /tmp/gh.tgz && \
    tar -xzf /tmp/gh.tgz -C /tmp && \
    mv /tmp/gh_${GH_VERSION}_linux_${arch}/bin/gh /usr/local/bin/gh

# uv
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

# pnpm (fast + reproducible)
RUN npm install -g corepack
RUN corepack enable
RUN corepack prepare pnpm@9.12.2 --activate

# gvm
RUN curl -fsSL https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer | bash

# oh-my-zsh
RUN su - vscode -c 'set -e; RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' \
    && ls -la /home/vscode/.zshrc

# pre-commit
RUN curl --proto '=https' --tlsv1.2 -LsSf https://github.com/j178/prek/releases/download/v0.4.8/prek-installer.sh | sh


# --------------------------------------------------
# runtime user
# --------------------------------------------------
USER vscode