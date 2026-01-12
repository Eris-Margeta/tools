#!/bin/bash
# Script for copying the contents of a file into the clipborad

if [[ -f "$1" ]]; then # Checks for existence of target file
  cat "$1" | pbcopy
  echo "Contents of'$1' is copied to clipboard"
else
  echo "Error: File '$1' doesn't exist"
fi

# usage: add alias for clip to shell env file (.bashrc or .zshrc)
# alias clip="~/clipboard.sh"
# then use it:
# clip (file name/path): "clip clipboard.sh"
#
