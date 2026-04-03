#!/bin/bash
# gpg_sync.sh
# Usage:
#   ./gpg_sync.sh to      # export all WSL keys to Windows
#   ./gpg_sync.sh from    # import all Windows keys to WSL

set -eou pipefail

GITHUB_USERNAME=$(whoami)

export_keys_to_windows() {
    TEMP_KEY=$(mktemp)

    gpg --export > "$TEMP_KEY"
    gpg --export-secret-keys >> "$TEMP_KEY"

    WIN_KEY="C:\\Users\\$GITHUB_USERNAME\\AppData\\Local\\Temp\\all_keys.asc"
    cp "$TEMP_KEY" "$(wslpath "$WIN_KEY")"

    powershell.exe -Command "gpg --import --yes '$WIN_KEY'"
    powershell.exe -Command "Remove-Item '$WIN_KEY' -ErrorAction SilentlyContinue"

    rm -f "$TEMP_KEY"
    echo "Keys exported to Windows successfully."
}

export_ownertrust_to_windows() {
    TEMP_TRUST=$(mktemp)

    # Keep only valid ownertrust lines, remove comments
    gpg --export-ownertrust | grep -E '^[0-9A-F]+:[0-6]:' > "$TEMP_TRUST"

    WIN_TRUST="C:\\Users\\$GITHUB_USERNAME\\AppData\\Local\\Temp\\all_trust.txt"
    cp "$TEMP_TRUST" "$(wslpath "$WIN_TRUST")"

    powershell.exe -Command "gpg --import-ownertrust --yes '$WIN_TRUST'"
    powershell.exe -Command "Remove-Item '$WIN_TRUST' -ErrorAction SilentlyContinue"

    rm -f "$TEMP_TRUST"
    echo "Ownertrust exported to Windows successfully."
}

import_windows_keys() {
    powershell.exe -Command 'gpg --export --output $env:TEMP\all_public_keys.asc --yes'
    powershell.exe -Command 'gpg --export-secret-keys --output $env:TEMP\all_secret_keys.asc --yes'

    WIN_PUBLIC_KEY=$(wslpath "C:\\Users\\$GITHUB_USERNAME\\AppData\\Local\\Temp\\all_public_keys.asc")
    WIN_SECRET_KEY=$(wslpath "C:\\Users\\$GITHUB_USERNAME\\AppData\\Local\\Temp\\all_secret_keys.asc")

    echo "Importing all public keys into WSL..."
    gpg --import "$WIN_PUBLIC_KEY"

    echo "Importing all secret keys into WSL..."
    gpg --import "$WIN_SECRET_KEY"

    rm -f "$WIN_PUBLIC_KEY" "$WIN_SECRET_KEY"

    echo "Public and secret keys imported successfully."
}

import_windows_ownertrust() {
    powershell.exe -Command "gpg --export-ownertrust | Where-Object { \$_ -match '^[0-9A-F]+:[0-6]:' } | Set-Content -Encoding ascii \$env:TEMP\\all_trust.txt"

    WIN_TRUST=$(wslpath "C:\\Users\\$GITHUB_USERNAME\\AppData\\Local\\Temp\\all_trust.txt")

    if [[ -f $WIN_TRUST   ]]; then
        echo "Importing cleaned owner trust into WSL..."
        gpg --import-ownertrust "$WIN_TRUST"
    fi

    rm -f "$WIN_TRUST"

    echo "Owner trust imported successfully."
}

# =========================
# Main
# =========================
case "$1" in
    to)
        export_keys_to_windows
        export_ownertrust_to_windows
        ;;
    from)
        import_windows_keys
        import_windows_ownertrust
        ;;
    *)
        echo "Usage: $0 to|from"
        exit 1
        ;;
esac
