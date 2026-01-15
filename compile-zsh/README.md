# Compile Zsh

A simple utility script that compiles your Zsh configuration files into bytecode for faster shell startup times.

## Overview

Zsh can load pre-compiled `.zwc` files instead of parsing plain text configuration files on every shell launch. This script automates the process of compiling your core Zsh config files, which can noticeably speed up shell initialization - especially useful if you have complex configurations.

## Features

- **Automatic cleanup**: Removes existing `.zwc` files before recompiling to ensure fresh builds
- **Compiles core config files**:
  - `~/.zshenv`
  - `~/.zshrc`
  - `~/.zprofile`
- **Safe operation**: Skips files that don't exist on your system
- **Verbose output**: Shows exactly what's being cleaned and compiled

## Usage

1. Make the script executable:
   ```bash
   chmod +x compile-zsh.sh
   ```

2. Run the script:
   ```bash
   ./compile-zsh.sh
   ```

## How It Works

The script uses Zsh's built-in `zcompile` command to create `.zwc` (Zsh Word Code) files. When Zsh starts, it automatically detects and loads these compiled files instead of parsing the original text files, resulting in faster startup.

## Notes

- Run this script after making changes to your Zsh configuration files
- The compiled files are architecture-specific - recompile if you migrate to a different system
- If something goes wrong with your shell, simply delete the `.zwc` files and Zsh will fall back to the original configs
