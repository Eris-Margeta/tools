#!/bin/bash

# A script to uninstall, clean, and reinstall Neovim from source with release optimizations.
# It also ensures the correct tree-sitter version is installed and sets up a new config.
# Assumes the Neovim repository is cloned at ~/neovim.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Helper Functions ---

# Function to compare version numbers (handles versions like 0.23.0)
version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }

# --- Configuration ---

# Define the Neovim source directory
NEOVIM_DIR="$HOME/neovim"
# Define the Neovim config directory
NVIM_CONFIG_DIR="$HOME/.config/nvim"
# Define the Git repository for the Neovim configuration
CONFIG_REPO="https://github.com/Eris-Margeta/mac-nvim-config"
# Required tree-sitter version
REQUIRED_TS_VERSION="0.25.0"
# tree-sitter binary URL for macOS ARM64
TREE_SITTER_URL="https://github.com/tree-sitter/tree-sitter/releases/download/v0.25.10/tree-sitter-macos-arm64.gz"
TREE_SITTER_ARCHIVE_NAME="tree-sitter-macos-arm64.gz"
TREE_SITTER_BIN_NAME="tree-sitter-macos-arm64"

# --- Pre-flight Checks ---

# Check if the Neovim source directory exists
if [ ! -d "$NEOVIM_DIR" ]; then
  echo "Error: Neovim source directory not found at $NEOVIM_DIR"
  echo "Please clone the Neovim repository into your home folder."
  exit 1
fi

# Refresh sudo timestamp at the beginning
echo "Requesting sudo privileges for installation..."
sudo -v

# --- Step 1: Uninstall and Clean Existing Neovim ---
echo "--- Starting Full Uninstall and Clean Process ---"

# Uninstall from source
echo "Navigating to the Neovim source directory..."
cd "$NEOVIM_DIR"

echo "Attempting to run 'make uninstall'..."
if sudo make uninstall 2>/dev/null; then
  echo "Standard uninstall successful."
else
  echo "'make uninstall' target not found or failed. Proceeding with manual removal."
  sudo rm -f /usr/local/bin/nvim
  sudo rm -rf /usr/local/share/nvim
  sudo rm -rf /usr/local/lib/nvim
  sudo rm -f /usr/local/share/man/man1/nvim.1
  echo "Manual removal of common file locations complete."
fi

# Clean the build directory
echo "Cleaning the build directory with 'make distclean'..."
make distclean

# Remove Neovim data, state, cache, and config directories
echo "Removing Neovim data, state, and cache directories..."
rm -rf ~/.local/share/nvim
rm -rf ~/.local/state/nvim
rm -rf ~/.cache/nvim
echo "Neovim cache and data directories removed."

echo "Removing existing Neovim configuration directory..."
rm -rf "$NVIM_CONFIG_DIR"
echo "Configuration directory removed."

echo "--- Uninstall and Clean Process Finished ---"
echo

# --- Step 2: Check and Install Tree-sitter ---
echo "--- Checking and Installing Tree-sitter ---"

INSTALL_TREE_SITTER=false
if ! command -v tree-sitter &>/dev/null; then
  echo "tree-sitter is not installed. Scheduling for installation."
  INSTALL_TREE_SITTER=true
else
  CURRENT_TS_VERSION=$(tree-sitter --version | awk '{print $2}')
  echo "Found tree-sitter version: $CURRENT_TS_VERSION"
  if version_gt "$REQUIRED_TS_VERSION" "$CURRENT_TS_VERSION"; then
    echo "tree-sitter version is older than required ($REQUIRED_TS_VERSION). Scheduling for upgrade."
    INSTALL_TREE_SITTER=true
  else
    echo "tree-sitter version is up to date."
  fi
fi

if [ "$INSTALL_TREE_SITTER" = true ]; then
  echo "Downloading new tree-sitter version..."
  curl -L -o "$TREE_SITTER_ARCHIVE_NAME" "$TREE_SITTER_URL"

  echo "Decompressing archive..."
  gunzip "$TREE_SITTER_ARCHIVE_NAME"

  echo "Making the binary executable..."
  chmod +x "$TREE_SITTER_BIN_NAME"

  echo "Moving the binary to /usr/local/bin/tree-sitter..."
  sudo mv "$TREE_SITTER_BIN_NAME" /usr/local/bin/tree-sitter

  echo "Verifying the new version..."
  tree-sitter --version
fi

echo "--- Tree-sitter Check Finished ---"
echo

# --- Step 3: Build and Install Neovim ---
echo "--- Starting Optimized Build and Installation of Neovim ---"

cd "$NEOVIM_DIR"

# Build Neovim with release optimizations
echo "Building Neovim with CMAKE_BUILD_TYPE=Release..."
make CMAKE_BUILD_TYPE=Release

# Install the newly built Neovim
echo "Installing Neovim..."
sudo make install

echo "--- Neovim Build and Installation Finished ---"
echo

# --- Step 4: Install New Neovim Configuration ---
echo "--- Installing New Neovim Configuration ---"

echo "Cloning configuration from $CONFIG_REPO..."
# Clone directly into the target directory, ensuring it's empty
git clone "$CONFIG_REPO" "$NVIM_CONFIG_DIR"

echo "--- Configuration Installation Finished ---"
echo

# --- Step 5: Verify Installation ---
echo "--- Verifying Final Installation ---"

# Check the build type of the newly installed nvim
INSTALLED_NVIM_PATH=$(which nvim)
if [ -z "$INSTALLED_NVIM_PATH" ]; then
  echo "Error: 'nvim' command not found in PATH after installation."
  exit 1
fi

echo "Neovim executable found at: $INSTALLED_NVIM_PATH"
echo "Checking build type..."
BUILD_TYPE=$($INSTALLED_NVIM_PATH --version | grep "Build type")

echo "$BUILD_TYPE"

# Final confirmation
if [[ "$BUILD_TYPE" == *"Release"* ]]; then
  echo "Success! Neovim has been reinstalled with the 'Release' build type."
  echo "Your new configuration is in place. Open 'nvim' to continue setup (e.g., PackerSync)."
else
  echo "Warning: The build type is not 'Release'. Please check the script for errors."
fi

exit 0
