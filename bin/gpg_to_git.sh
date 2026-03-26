#!/bin/sh
# Writes gpg key to git


# todo: if no gpg, get it with bitwarden


gpg --list-secret-keys --keyid-format=long | grep sec | awk -F"/" '{print $2}' | awk '{print $1}'
