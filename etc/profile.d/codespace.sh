#!/bin/bash


# If not root
if [ "$(whoami)" != "root" ]; then

    # Check if running locally and set $RepositoryName if not already set
    if [[ "$CODESPACES" != "true" && -z "$RepositoryName" ]]; then
        export RepositoryName=$(ls -1t --color=never /workspaces | tail -1 | sed 's:/*$::')
        export LOCAL_WORKSPACE_FOLDER="/workspaces/$RepositoryName"
    fi

    # Rewrites URLs of the form http://HOST:PORT as https://$CODESPACE_NAME.app.github.dev:PORT
    _hostname() {

        # If in cloud
        if [[ "$CODESPACES" == "true" ]]; then
            local url="http://[^:]+:(\x1b\[[0-9;]*m)?([0-9]+)(\x1b\[[0-9;]*m)?"
            while read; do
                echo "$REPLY" | sed -E "s#${url}#https://${CODESPACE_NAME}-\2.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}#"
            done

        # Else if local
        else
            tee
        fi
    }

    # Filter out the http-server version information
    _version() {
        local version="http-server version:"
        while read; do
            if [[ ! $REPLY =~ ${version} ]]; then
                echo "$REPLY"
            fi
        done
    }

    # Configure prompt
    _prompt() {
        local dir="$(dirs +0)" # CWD with ~ for home
        dir="${dir%/}/" # Remove trailing slash (in case in /) and then re-append
        dir=${dir#"/workspaces/$RepositoryName/"} # Left-trim workspace
        dir="${dir} $ " # Add prompt
        dir=${dir#" "} # Trim leading whitespace (in case in workspace)
        echo -n "${dir}"
    }
    PS1='$(_prompt)'

    # Configure cd to default to workspace
    alias cd="HOME=\"/workspaces/$RepositoryName\" cd"

    # Generate a diagnostic report for troubleshooting
    diagnose() {
        code /workspaces/$RepositoryName/diagnose.log && \
        cat /etc/issue > diagnose.log && \
        code --list-extensions >> diagnose.log
    }

    # Rewrite URLs in stdout
    http-server() {
        command http-server "$@" | _hostname | _version | uniq
    }
fi


# Set up PATH
export PATH="/opt/bin:${PATH}"

# Common aliases (language-agnostic)
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Git configuration (if needed)
if [ -n "${CODESPACES}" ]; then
    git config --global --replace-all credential.helper "/opt/bin/gitcredential.sh"
fi

# Welcome message
echo "🚀 Welcome to your Codespace!"
echo "📦 Tools available: gh, act, docker, uv, pnpm, gvm, pre-commit"
echo "🔧 Type 'help' for available commands"
