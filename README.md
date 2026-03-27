```sh
# Windows
.\windows\setup.ps1
```

```sh
# Setup on linux or WSL:
bin/infra.sh install_packages
bin/infra.sh setup_env
# setup_env will move binaries to ~/bin. Follow the instructions to complete the chezmoi setup to update path so they're available globally

# run everything:
bin/infra.sh setup_everything

# Install on the windows host of a WSL, requires `.\windows\setup.ps1` to have been run on the host machine at least once
bin/wsl/infra_windows.sh <command>
```


TODO:
* fix all permissions and keep them consistent with git settings/vscode/precommit hooks
* set the fucking vscode settings to view staged files as tree mode
* how to share ubloc settings/userscripts/extensions for browsers?
* https://stackoverflow.com/questions/8264655/how-to-make-powershell-tab-completion-work-like-bash
* add docker compose configs, swap to traefik, add prometheus alarms
* switch to versioned configs for everything *arr
* find huntarr replacement
* look into firefox user.json?
