#!/usr/bin/env bash

# Import this file adding this at the top:
# source "$(dirname "$(dirname "$(readlink -f "$0")")")/lib/common.sh"

#################### SCRIPT SAFEGUARDS ####################

if [[ $- != *i* ]]; then
    set -e              # stop if any command has exit status == 0
    set -E              # inherit traps so that cleanup() can work
    set -o pipefail     # prevent nested errors from being masked
    set -u              # stop if any variable is unset

    # makes sure that if a command fails due to set -e, it says why:
    trap 'echo "Failed at line $LINENO: $BASH_COMMAND"' ERR
fi

#################### COMMON VARIABLES ####################

if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
     export PATH="$PATH:$HOME/bin"
fi

# shellcheck disable=SC2155
export SCRIPT_DIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
export BIN_DIR="$HOME/bin"
export MISE_INSTALL_PATH="$BIN_DIR/mise"

#################### COMMON FUNCTIONS ####################

# check if we're running as root
function abort_if_root {
    if [[ $EUID -eq 0 ]]; then
        echo "Error: do not run this script as root or with sudo."
        exit 1
    fi
}

# check if a variable is blank
function is_blank_variable {
    [[ -z ${1//[[:space:]]/}  ]]
}

cleanup_cmds=()
_cleanup_done=0

# run cleanup code added to the cleanup_cmds array
function cleanup {
    local exit_code=$?
    [[ $_cleanup_done -eq 1 ]] && return
    _cleanup_done=1
    for ((i = ${#cleanup_cmds[@]} - 1; i >= 0; i--)); do
        echo "[CLEANUP] running cleanup: ${cleanup_cmds[$i]}"
        eval "${cleanup_cmds[$i]}" || true
    done
    exit "$exit_code"
}

trap cleanup EXIT INT TERM ERR
