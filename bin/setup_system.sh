#!/usr/bin/env bash
# Install required prerequisites.

source "$(dirname "$(dirname "$(readlink -f "$0")")")/lib/common.sh"

abort_if_root

# Create symlinks to $HOME/bin
function create_bin_link {
    mkdir -p "$BIN_DIR"
    ln -sf "$SCRIPT_DIR/bin/infra.sh" "$BIN_DIR/infra.sh"
}

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

function install_missing_mise_tools {
    mise install -q
}

function check_or_install_zsh {
    current_shell=$(getent passwd "$USER" | awk -F: '{print $NF}' | awk -F/ '{print $NF}')
    if [[ $current_shell != *zsh ]]; then
        echo "Current shell is $current_shell != /bin/zsh. Installing..."

        if ! command -v zsh; then
            sudo apt-get install -y zsh # TODO: abstract this to use the system's package manager
        fi

        echo "Setting ZSH as shell for user $USER."
        sudo usermod --shell /bin/zsh "$USER"
    fi

    if [[ ! -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi
}

function set_ssh_for_github {
    # Export GPG key as SSH public key if not already done
    pub_ssh_key="$HOME/.ssh/id_rsa_github_$USER.pub"
    if [[ ! -f $pub_ssh_key ]]; then
        echo "Exporting gpg key to $pub_ssh_key"
        gpg --export-ssh-key "$(chezmoi data | jq -r '.signingKey')" > "$pub_ssh_key"
    fi

    # Point SSH to gpg-agent socket so it uses your GPG auth key
    # shellcheck disable=SC2155
    export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
    # this needs to be global or ssh for github via gpg won't work

    # Make sure gpg-agent is running
    # gpg-connect-agent /bye > /dev/null 2>&1

    # Register the auth subkey with gpg-agent if not already there
    if [[ ! -f ~/.gnupg/sshcontrol ]]; then
        auth_keygrip=$(gpg --list-keys --with-keygrip "$(chezmoi data | jq -r '.signingKey')" 2> /dev/null |
            awk '/\[A\]/{found=1} found && /Keygrip/{print $3; exit}')

        echo "Registering auth keygrip $auth_keygrip with gpg-agent"
        if [[ -n $auth_keygrip ]] && ! grep -q "$auth_keygrip" ~/.gnupg/sshcontrol 2> /dev/null; then
            echo "$auth_keygrip" >> ~/.gnupg/sshcontrol
        fi
    fi

    # Authenticate with GitHub if needed
    if ! grep -q "oauth_token" ~/.config/gh/hosts.yml; then
        gh auth login --hostname github.com --git-protocol ssh --web
        gh auth setup-git
    fi
}

function check_prerequisites {
    create_bin_link
    check_or_install_mise
    check_or_import_gpg

    check_or_install_chezmoi
    apply_chezmoi

    install_missing_mise_tools
    check_or_install_zsh
    set_ssh_for_github
}

check_prerequisites
