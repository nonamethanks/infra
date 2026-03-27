#!/bin/bash

set -eou pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Error: do not run this script as root or with sudo."
    exit 1
fi

ANSIBLE_BIN="ansible"
SCRIPTPATH=$(dirname "$(readlink -f "$0")")
REPO_DIR=$(dirname "$SCRIPTPATH")

function check_ansible {
    # Checks if ansible is installed
    echo "Checking ansible..."

    if ! command -v "$ANSIBLE_BIN" &>/dev/null; then
        ANSIBLE_BIN="$HOME/.local/bin/ansible"
    fi

    if command -v "$ANSIBLE_BIN" &>/dev/null; then
        echo "Ansible is already installed: $($ANSIBLE_BIN --version | head -1)"
        return
    fi

    echo -e "Ansible not found. Installing...\n"
    sudo apt-get -y update
    sudo apt-get -y install pipx
    pipx install --include-deps ansible

    $ANSIBLE_BIN --version
}

function main() {
    if (($# == 0)); then
        echo "Usage: $(basename "$0") <command> [OPTIONS]"
        echo "Commands:"
        echo "  install"
        exit 1
    fi

    local command="$1"
    shift

    case "$command" in
        install)
            command_install "$@"
            ;;
        *)
            echo "Error: unknown command '$command'"
            echo "Usage: $(basename "$0") <command> [OPTIONS]"
            echo "Commands:"
            echo "  install"
            exit 1
            ;;
    esac
}

function command_install {
    # Install all packages on Linux
    local ansible_args=("$@")

    check_ansible

    # If windows target is requested, install Windows ansible modules and
    # do not ask for Linux become password.
    if command_install_target_is_windows "${ansible_args[@]}"; then
        ensure_windows_ansible_modules
    else
        ansible_args+=("--ask-become-pass")
    fi

    set -x
    "$ANSIBLE_BIN-playbook" "$REPO_DIR/ansible/install.yaml" "${ansible_args[@]}"
    { set +x; } 2>/dev/null

    echo "Done!"
}

function ensure_windows_ansible_modules {
    pipx inject ansible "pywinrm>=0.4.0"
}

function command_install_target_is_windows {
    local arg
    for arg in "$@"; do
        if [[ "$arg" =~ (^|[[:space:]])target_os=windows($|[[:space:]]) ]]; then
            return 0
        fi
    done

    return 1
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
