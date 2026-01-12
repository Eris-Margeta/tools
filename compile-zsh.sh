#!/bin/zsh

# Files to compile
FILES=(
  "$HOME/.zshenv"
  "$HOME/.zshrc"
  "$HOME/.zprofile"
)

# Clean up old .zwc files
echo "Cleaning up old .zwc files..."
for file in "${FILES[@]}"; do
  if [ -f "$file.zwc" ]; then
    rm -v "$file.zwc"
  fi
done
echo "Old .zwc files removed."

# Compile new .zwc files
echo "Compiling new .zwc files..."
for file in "${FILES[@]}"; do
  if [ -f "$file" ]; then
    zcompile "$file"
    echo "Compiled: $file -> $file.zwc"
  else
    echo "Skipped: $file (file not found)"
  fi
done
echo "Compilation complete!"
