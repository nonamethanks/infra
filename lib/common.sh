#!/usr/bin/env bash

# Import this file adding this at the top:
# source "$(dirname "$(dirname "$(readlink -f "$0")")")/lib/common.sh"

#################### SCRIPT SAFEGUARDS ####################

if [[ $- != *i* ]]; then
    set -e              # stop if any command has exit status == 0
    set -o pipefail     # prevent nested errors from being masked
    set -u              # stop if any variable is unset

    # makes sure that if a command fails due to set -e, it says why:
    trap 'echo "Failed at line $LINENO: $BASH_COMMAND"' ERR
fi

#################### COMMON VARIABLES ####################
# shellcheck disable=SC2155
export SCRIPT_DIR="$(dirname "$(dirname "$(readlink -f "$0")")")"

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
