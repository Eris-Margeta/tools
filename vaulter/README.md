# Bash Script for File and Repository Management

## Overview

This script is a utility tool designed to automate common file management, encryption, compression, Git repository initialization, and GitLab/GitHub remote management tasks. It simplifies workflows for developers by providing an interactive menu-driven interface.

---

## Features

1. **Set Absolute Folder Path**:

   - Allows setting a folder path as a default for subsequent operations.
   - Displays the current path if already set.

2. **Compression**:

   - Compresses a folder into a `.tar.gz` file with maximum compression using `pigz`.
   - Output file is saved in the same folder.

3. **Encryption**:

   - Encrypts a file using AES-256 encryption via `openssl`.
   - Requires a password and confirmation to generate a `.enc` file.

4. **Git LFS Initialization**:

   - Initializes a Git repository for a specified folder.
   - Sets up `.gitignore` (ignoring `.DS_Store`), enables Git LFS, tracks all files, and commits with an initial message.

5. **Push to Remote Origin**:

   - Adds a remote origin to a Git repository and pushes all changes to the `main` branch.
   - Validates the existence of a Git repository before proceeding.

6. **Decryption**:

   - Decrypts an `.enc` file using AES-256.
   - If multiple `.enc` files exist in a folder, the script prompts the user to select one.

7. **Decompression**:

   - Decompresses a `.tar.gz` file in a specified folder.
   - If multiple `.tar.gz` files are present, the script prompts the user to select one.

8. **Documentation**:
   - Displays installation requirements and additional instructions.

---

## Prerequisites

Ensure the following tools are installed on your system:

- `pigz`: For high-speed, multi-threaded compression.
- `openssl`: For file encryption and decryption.
- `git`: For Git repository management.
- `git-lfs`: For handling large files in Git repositories.

### Installation

#### macOS

```bash
brew install pigz openssl git git-lfs

#### Debian/Ubuntu:
sudo apt install pigz openssl git git-lfs


### Usage

1. make the script executable:
chmod +x script.sh

2. Execute the script:
./vaulter.sh


```
