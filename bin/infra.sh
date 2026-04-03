#!/usr/bin/env bash
# Entrypoint to manage a system.

source "$(dirname "$(dirname "$(readlink -f "$0")")")/lib/common.sh"

abort_if_root

# required vars for a first run when zsh is not set up yet
export PATH="$PATH:$HOME/bin"
export MISE_INSTALL_PATH=$HOME/bin/mise

# Install mise if missing
function check_or_install_mise {
    if command -v mise > /dev/null; then return; fi
    echo "Installing mise."
    curl https://mise.run | sh

    eval "$(mise activate bash)"
    mise reshim
}

# Import GPG keys from bitwarden if they are missing
function check_or_import_gpg {
    if ! command -v gpg > /dev/null; then
        echo "gpg must be installed."
        exit 1
    fi

    if [[ -n "$(gpg --list-keys)" ]]; then
        return
    fi

    mise use bitwarden jq@1 --silent
    "$SCRIPT_DIR/bin/gpg_backup.sh" import
}

function check_or_install_chezmoi {
    if [[ ! -f $HOME/.config/chezmoi/chezmoi.yaml ]]; then
        mise use -g chezmoi
        echo "Installing chezmoi."
        chezmoi init --source "$SCRIPT_DIR/dotfiles"
    fi
}

function apply_chezmoi {
    chezmoi merge-all && chezmoi apply --interactive
}

function check_prerequisites {
    check_or_install_mise
    check_or_import_gpg

    check_or_install_chezmoi
    apply_chezmoi

    # check_or_install_zsh
    # set_ssh_for_github

    # echo "Basic parts of the system have been setup. Now run this to continue:."
    # echo "  infra.sh setup_everything"
}

function main {
    mkdir -p "$HOME/bin"
    check_prerequisites
}

main "$@"
