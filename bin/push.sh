#!/usr/bin/env bash
# Push dotfiles and repo in order

source "$(dirname "$(dirname "$(readlink -f "$0")")")/lib/common.sh"

# Check if the directory has git dirty state
function check_dirty {
    echo "Checking for dirty files: $1"
    local dir="$1"
    if ! git -C "$dir" diff --quiet || ! git -C "$dir" diff --cached --quiet; then
        echo "Error: $dir is in a dirty state. Commit first." >&2
        exit 1
    fi
}

# Check if the commits don't match expected author
function check_commits {
    local dir="$1"
    echo "Checking for bad commits: $dir"

    OK_USERNAME=$(chezmoi data | jq -r ".name")
    OK_EMAIL=$(chezmoi data | jq -r ".email")

    git -C "$dir" log '@{u}..HEAD' --format="%H %ae %an" | while read -r hash email name; do
        if [[ $email != "$OK_EMAIL" || $name != "$OK_USERNAME" ]]; then
            echo "Bad commit found:  $hash: '$name' <$email> does not match expected author '$OK_USERNAME' <$OK_EMAIL>"
            exit 1
        fi
    done
}

# Push to github
function push {
    local dir="$1"
    echo "Pushing: $dir"
    git -C "$dir" push
}

function main {
    check_dirty "$SCRIPT_DIR/dotfiles"
    check_commits "$SCRIPT_DIR/dotfiles"
    push "$SCRIPT_DIR/dotfiles"

    check_dirty "$SCRIPT_DIR"
    check_commits "$SCRIPT_DIR"
    push "$SCRIPT_DIR"
}

main
