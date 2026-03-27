#!/bin/bash

set -eou pipefail

SCRIPTPATH=$(dirname "$(readlink -f "$0")")

function main() {
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

    "$SCRIPTPATH/infra.sh" "$@"                             \
        -e "target_os=windows"                              \
        -e "ansible_host=$windows_host"                     \
        -e "ansible_connection=winrm"                       \
        -e "ansible_winrm_transport=credssp"                \
        -e "ansible_port=5986"                              \
        -e "ansible_winrm_server_cert_validation=ignore"    \
        -e "ansible_winrm_message_encryption=always"        \
        -e "@$tmp_vars"

    rm -f "$tmp_vars"
    trap - EXIT
}

main "$@"
