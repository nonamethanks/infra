#!/bin/bash

set -eou pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Error: do not run this script as root or with sudo."
    exit 1
fi

ANSIBLE_PATH="$HOME/.local/bin"
SCRIPTPATH=$(dirname "$(readlink -f "$0")")
REPO_DIR=$(dirname "$SCRIPTPATH")

function check_ansible {
    # Checks if ansible is installed
    echo "Checking ansible..."

    if [[ -f "$ANSIBLE_PATH/ansible" ]]; then
        echo "Ansible is already installed: $(\$ANSIBLE_PATH/ansible --version | head -1)"
        return
    fi

    echo -e "Ansible not found. Installing...\n"
    sudo apt-get -y update
    sudo apt-get -y install pipx
    pipx install --include-deps ansible

    "$ANSIBLE_PATH/ansible" --version
}

function main() {
    local show_help=false
    local phase=""
    local ansible_args=()

    while (($# > 0)); do
        case "$1" in
            -h|--help)
                show_help=true
                ;;
            *)
                ansible_args+=("$1")
                ;;
        esac
        shift
    done

    if [[ "$show_help" == "true" ]]; then
        if ((${#ansible_args[@]} > 0)) && [[ "${ansible_args[0]}" != -* ]]; then
            ansible_args=("${ansible_args[@]:1}")
        fi
        print_help "${ansible_args[@]}"
        return
    fi

    # Optional first positional argument is treated as phase; if omitted,
    # Ansible defaults/validation decide behavior.
    if ((${#ansible_args[@]} > 0)) && [[ "${ansible_args[0]}" != -* ]]; then
        phase="${ansible_args[0]}"
        ansible_args=("${ansible_args[@]:1}")
    fi

    run_phase "$phase" "${ansible_args[@]}"
}

function print_help {
    local ansible_args=("$@")

    echo "Usage: $(basename "$0") [phase] [ansible-playbook options]"
    echo "       $(basename "$0") -h [ansible-playbook options]"
    echo ""
    echo "Discovering available phases via Ansible..."
    run_phase "list_phases" "${ansible_args[@]}"
}

function run_phase {
    # Run infra playbook; phase handling and validation are defined in Ansible.
    local phase="$1"
    shift
    local ansible_args=("$@")

    check_ansible

    # For phase discovery/help, skip module installation and sudo prompts.
    if [[ "$phase" != "list_phases" ]]; then
        # If windows target is requested, install Windows ansible modules.
        if command_install_target_is_windows "${ansible_args[@]}"; then
            ensure_windows_ansible_modules
        else
            # Ask for sudo password on regular Linux execution.
            ansible_args+=("--ask-become-pass")
        fi
    fi

    local playbook_cmd=("$ANSIBLE_PATH/ansible-playbook" "$REPO_DIR/ansible/infra.yaml")
    if [[ -n "$phase" ]]; then
        playbook_cmd+=("-e" "phase=$phase")
    fi
    playbook_cmd+=("${ansible_args[@]}")
    set -x
    "${playbook_cmd[@]}"
    { set +x; } 2>/dev/null

    echo "Done!"
}

function ensure_windows_ansible_modules {
    pipx inject ansible "pywinrm>=0.4.0" requests-credssp
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
