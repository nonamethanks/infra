#!/usr/bin/env bash
# Entrypoint to manage a system.
source "$(dirname "$(dirname "$(readlink -f "$0")")")/lib/common.sh"

function main {
    local args=("$@")
    local command=""

    for i in "${!args[@]}"; do
        if [[ ${args[$i]} != -* ]]; then
            command="${args[$i]}"
            unset "args[$i]"
            args=("${args[@]}")
            break
        fi
    done

    "$SCRIPT_DIR/bin/setup_system.sh"

    local script="$SCRIPT_DIR/bin/${command}.sh"
    if [[ -n $command && $command != "setup_system" && -x $script ]]; then
        "$script" "${args[@]}"
    else
        if [[ -n $command ]] && [[ $command != "help" ]]; then
            echo "Command '$command' not implemented."
        fi
        echo -e "\n  List of commands:"
        find "$SCRIPT_DIR/bin" -maxdepth 1 -name '*.sh' -executable \
            ! -name 'setup_system.sh' \
            ! -name 'infra.sh' \
            -exec basename {} .sh \; | sort | sed 's/^/                    /'
        echo -e "\n"
        exit 1
    fi

    echo "Done!"
}

main "$@"
