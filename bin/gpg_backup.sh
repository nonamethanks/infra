#!/bin/bash

set -eou pipefail


function bitwarden_login {
    bw login || true

    BW_SESSION=$(bw unlock --raw)

    if [[ -z "${BW_SESSION// }" ]]; then
        echo "Could not unlock the session."
        exit 1
    fi

    export BW_SESSION
}


function get_or_create_backup_file {
    # check if backup item bw-gpg-backups already exists
    BW_BACKUP_OBJECT=$(bw list items --search "bw-gpg-backups")

    if [[ "$BW_BACKUP_OBJECT" == "[]" ]]; then
        echo "bw-gpg-backups item doesn't exist in bitwarden, creating it..."
        # if not, first search for the folder, called bw-backups
        BW_BACKUP_FOLDER_ID=$(bw list folders | jq -r '.[] | select(.name=="bw-backups").id // empty' | sort | head -1)
        if [[ -z "${BW_BACKUP_FOLDER_ID// }" ]]; then
            # if the folder doesn't exist, create it
            BW_BACKUP_FOLDER_ID=$(bw get template folder | jq '.name="bw-backups"' | bw encode | bw create folder | jq -r ".id")
        fi
        # finally, create the item in the folder
        BW_BACKUP_OBJECT=$(bw get template item \
            | jq '.type = 2 | .secureNote.type = 0 | .notes = "GPG Backups for automatic import and export." | .name = "bw-gpg-backups"' \
            | jq ".folderId = \"$BW_BACKUP_FOLDER_ID\"" \
            | bw encode \
            | bw create item )
    fi

    BW_BACKUP_ID=$(echo "$BW_BACKUP_OBJECT" | jq -r ".[0].id")
    BW_BACKUP_ATTACHMENTS=$(echo "$BW_BACKUP_OBJECT" | jq -r ".[0].attachments[].fileName")
}


function export_gpg_keys {
    # Export public and private keys
    for KEY in $(gpg --list-keys --with-colons | awk -F: '/^pub/{found=1} /^fpr/ && found{print $10; found=0}'); do
        filename="/tmp/pub_$KEY.asc"
        if echo "$BW_BACKUP_ATTACHMENTS" | grep -q "pub_$KEY.asc"; then
            echo "Key $KEY is already backed up."
            continue
        fi
        echo "Backing up public key $KEY"
        trap 'rm -f "$filename"' EXIT
        gpg -a --export "$KEY" > "$filename"
        bw create attachment --itemid "$BW_BACKUP_ID" --file "$filename" >/dev/null
        rm -f "$filename"
        trap - EXIT
    done

    for KEY in $(gpg --list-secret-keys --with-colons | awk -F: '/^sec/{found=1} /^fpr/ && found{print $10; found=0}'); do
        filename="/tmp/priv_$KEY.asc"
        if echo "$BW_BACKUP_ATTACHMENTS" | grep -q "priv_$KEY.asc"; then
            echo "Key $KEY is already backed up."
            continue
        fi
        echo "Backing up private key $KEY"
        trap 'rm -f "$filename"' EXIT
        gpg --pinentry-mode loopback -a --export-secret-keys "$KEY" > "$filename"
        bw create attachment --itemid "$BW_BACKUP_ID" --file "$filename" >/dev/null
        rm -f "$filename"
        trap - EXIT
    done
}


function export_ownertrust {
    # Merge and export ownertrust
    filename="/tmp/otrust.txt"
    current_otrust=$(gpg --export-ownertrust | grep -v '^#')

    if echo "$BW_BACKUP_ATTACHMENTS" | grep -q "otrust.txt"; then
        echo "Ownertrust backup found, merging..."
        attachment_id=$(echo "$BW_BACKUP_OBJECT" | jq -r '.[0].attachments[] | select(.fileName=="otrust.txt").id')
        backed_up_otrust=$(bw get attachment "$attachment_id" --itemid "$BW_BACKUP_ID" --raw)

        # Merge: combine both, sort by fingerprint keeping highest trust level
        merged=$(echo -e "$current_otrust\n$backed_up_otrust" | grep -v '^#' | grep -v '^$' | sort -t: -k1,1 -k2,2rn | awk -F: '!seen[$1]++')

        if [[ "$merged" == "$backed_up_otrust" ]]; then
            echo "Ownertrust is already up to date, skipping."
            return
        fi

        echo "Ownertrust changed, updating backup..."
        # Delete old attachment and re-upload
        bw delete attachment "$attachment_id" --itemid "$BW_BACKUP_ID" >/dev/null
    else
        echo "No ownertrust backup found, creating..."
        merged="$current_otrust"
    fi

    trap 'rm -f "$filename"' EXIT
    echo "$merged" > "$filename"
    bw create attachment --itemid "$BW_BACKUP_ID" --file "$filename" >/dev/null
    rm -f "$filename"
    trap - EXIT
}


function import_gpg_keys {
    # Import public and private keys
    for file in $(echo "$BW_BACKUP_ATTACHMENTS" | grep -E '^(pub|priv)_[A-F0-9]{40}\.asc$'); do
        fingerprint=$(echo "$file" | grep -oP '[A-F0-9]{40}')

        if [[ "$file" == priv_* ]]; then
            if gpg --list-secret-keys "$fingerprint" &>/dev/null; then
                echo "Key $fingerprint already exists, skipping $file"
                continue
            fi
        else
            if gpg --list-keys "$fingerprint" &>/dev/null; then
                echo "Key $fingerprint already exists, skipping $file"
                continue
            fi
        fi

        echo "Importing $file..."
        attachment_id=$(echo "$BW_BACKUP_OBJECT" | jq -r ".[0].attachments[] | select(.fileName==\"$file\").id")
        tmpfile="/tmp/$file"

        trap 'rm -f "$tmpfile"' EXIT
        bw get attachment "$attachment_id" --itemid "$BW_BACKUP_ID" --raw > "$tmpfile"
        gpg --import "$tmpfile" >/dev/null
        rm -f "$tmpfile"
        trap - EXIT
    done
}

function import_ownertrust {
    # Import and merge ownertrust
    if echo "$BW_BACKUP_ATTACHMENTS" | grep -q "otrust.txt"; then
        echo "Importing ownertrust..."
        attachment_id=$(echo "$BW_BACKUP_OBJECT" | jq -r '.[0].attachments[] | select(.fileName=="otrust.txt").id')
        backed_up_otrust=$(bw get attachment "$attachment_id" --itemid "$BW_BACKUP_ID" --raw)
        current_otrust=$(gpg --export-ownertrust | grep -v '^#')

        merged=$(echo -e "$current_otrust\n$backed_up_otrust" | grep -v '^#' | grep -v '^$' | sort -t: -k1,1 -k2,2rn | awk -F: '!seen[$1]++')

        echo "$merged" | gpg --import-ownertrust
    fi
}


function command_export {
    PUBLIC_KEYS=$(gpg -a --export)

    if [[ -z "$PUBLIC_KEYS" ]]; then
        echo "Nothing to export."
        exit 0
    fi

    bitwarden_login
    bw sync

    get_or_create_backup_file

    export_gpg_keys
    export_ownertrust
}


function command_import {
    bitwarden_login
    bw sync

    get_or_create_backup_file

    import_gpg_keys
    import_ownertrust
}


function main() {
    # Main loop
    command=${1:-export}

    if (($# > 0)); then
        shift
    fi

    case "$command" in
        export)
            command_export "$@"
            ;;
        import)
            command_import "$@"
            ;;
        *)
            echo "Command $command unknown. Allowed commands: import|export."
            exit 1
            ;;
    esac

    echo "Done!"
}


main "$@"
