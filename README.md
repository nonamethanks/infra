```sh
# Windows
.\windows\setup.ps1
```

```sh
# First time installation

# Install on linux or WSL:
bin/infra.sh install

# Install on the windows host of a WSL, requires `.\windows\setup.ps1` to have been run on the host machine at least once
bin/infra.sh wininstall
```


TODO:
* fix all permissions and keep them consistent with git settings/vscode/precommit hooks
* set the fucking vscode settings to view staged files as tree mode
