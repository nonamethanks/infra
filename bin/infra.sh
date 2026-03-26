#!/bin/bash

set -eou pipefail

ANSIBLE_BIN="ansible"
SCRIPTPATH=$(dirname "$(readlink -f "$0")")
REPO_DIR=$(dirname "$SCRIPTPATH")

function check_ansible {

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

function check_ansible_windows {
    check_ansible

    pipx inject ansible "pywinrm>=0.4.0"
}

function main() {
    command=${1:-install}

    if (($# > 0)); then
        shift
    fi

    case "$command" in
        install)
            command_install_linux "$@"
            ;;
        wininstall)
            command_install_windows "$@"
            ;;
        *)
            echo "Command $command unknown."
            exit 1
            ;;
    esac
}

function command_install_linux {
    check_ansible

    set -x
    ANSIBLE_CONFIG=$REPO_DIR/ansible.cfg "$ANSIBLE_BIN-playbook" "$REPO_DIR/ansible/install.yaml" --ask-become-pass "$@"
    set +x

    echo "Done!"
}

function command_install_windows {
    check_ansible_windows

    read -rsp "Windows password: " win_pass
    echo

    # In WSL2, localhost is the Linux VM. Default to the Windows host gateway IP.
    windows_host=${WINDOWS_HOST:-$(awk '/^nameserver / { print $2; exit }' /etc/resolv.conf)}

    tmp_vars=$(mktemp)
    trap 'rm -f "$tmp_vars"' EXIT
    printf '{"ansible_user": %s, "ansible_password": %s}' \
        "$(printf '%s' ".\\$USER" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
        "$(printf '%s' "$win_pass" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')" \
        > "$tmp_vars"

    set -x

    ANSIBLE_CONFIG=$REPO_DIR/ansible.cfg "$ANSIBLE_BIN-playbook" "$REPO_DIR/ansible/install.yaml"     \
        -e "target_os=windows"                                      \
        -e "ansible_host=$windows_host"                             \
        -e "ansible_connection=winrm"                               \
        -e "ansible_winrm_transport=credssp"                        \
        -e "ansible_port=5986"                                      \
        -e "ansible_winrm_server_cert_validation=ignore"            \
        -e "ansible_winrm_message_encryption=always"                \
        -e "@$tmp_vars" \
        "$@"
    set +x

    echo "Done!"
}

main "$@"
