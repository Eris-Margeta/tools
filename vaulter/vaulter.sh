#!/bin/bash

# ============================================================================
# VAULTER V2 - Secure Folder Backup System
# ============================================================================
# Create encrypted backups of folders and store them in Git LFS repositories
# for secure remote storage.
#
# Workflow:
#   VAULT:    folder → compress → encrypt → git lfs → push
#   DE-VAULT: pull → decrypt → decompress → folder
# ============================================================================

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

PBKDF2_ITERATIONS=600000
CIPHER="aes-256-cbc"
VERSION="2.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Working path (persists during session)
working_path=""

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

print_header() {
    clear
    echo -e "${BOLD}${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    VAULTER V2                                 ║"
    echo "║              Secure Folder Backup System                      ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}→ $1${NC}"; }
print_step() { echo -e "${BOLD}${BLUE}[$1]${NC} $2"; }

confirm_action() {
    local prompt="$1"
    local response
    read -r -p "$prompt (y/n): " response
    [[ "$response" =~ ^[Yy]$ ]]
}

check_prerequisites() {
    local missing=()

    command -v pigz >/dev/null 2>&1 || missing+=("pigz")
    command -v openssl >/dev/null 2>&1 || missing+=("openssl")
    command -v git >/dev/null 2>&1 || missing+=("git")
    command -v git-lfs >/dev/null 2>&1 || missing+=("git-lfs")

    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing required tools: ${missing[*]}"
        echo
        echo "Install with:"
        echo "  macOS:  brew install ${missing[*]}"
        echo "  Linux:  sudo apt install ${missing[*]}"
        return 1
    fi
    return 0
}

secure_delete() {
    local file="$1"
    if [ -f "$file" ]; then
        if command -v shred >/dev/null 2>&1; then
            shred -u "$file" 2>/dev/null || rm -f "$file"
        elif command -v gshred >/dev/null 2>&1; then
            gshred -u "$file" 2>/dev/null || rm -f "$file"
        else
            rm -f "$file"
        fi
        return 0
    fi
    return 1
}

get_folder_path() {
    local prompt="$1"
    local folder

    if [ -n "$working_path" ] && [ -d "$working_path" ]; then
        echo "Current working path: $working_path"
        if confirm_action "Use this path?"; then
            echo "$working_path"
            return 0
        fi
    fi

    read -r -p "$prompt: " folder
    echo "$folder"
}

# ============================================================================
# VAULT WORKFLOW
# ============================================================================

vault_folder() {
    echo
    echo -e "${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}                         VAULT FOLDER                           ${NC}"
    echo -e "${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo
    echo "This will create an encrypted backup of your folder:"
    echo "  1. Compress the folder (tar.gz with pigz)"
    echo "  2. Encrypt with AES-256 + PBKDF2"
    echo "  3. Create a Git LFS repository"
    echo "  4. Optionally push to remote"
    echo
    echo -e "${YELLOW}Only the encrypted file will be stored in the vault.${NC}"
    echo

    # Get source folder
    local source_folder
    source_folder=$(get_folder_path "Enter the folder path to vault")

    # Validate
    if [ ! -d "$source_folder" ]; then
        print_error "Folder does not exist: $source_folder"
        return 1
    fi

    # Remove trailing slash and resolve path
    source_folder="${source_folder%/}"
    source_folder="$(cd "$source_folder" && pwd)"

    local folder_name=$(basename "$source_folder")
    local parent_dir=$(dirname "$source_folder")
    local vault_dir="${parent_dir}/${folder_name}-vault"
    local archive_file="${parent_dir}/${folder_name}.tar.gz"
    local encrypted_file="${parent_dir}/${folder_name}.tar.gz.enc"

    echo
    echo "┌─────────────────────────────────────────────────────────────────┐"
    echo "│ SUMMARY                                                         │"
    echo "├─────────────────────────────────────────────────────────────────┤"
    printf "│ %-63s │\n" "Source: $source_folder"
    printf "│ %-63s │\n" "Vault:  $vault_dir"
    echo "└─────────────────────────────────────────────────────────────────┘"
    echo

    if ! confirm_action "Proceed with vault creation?"; then
        print_info "Cancelled"
        return 0
    fi

    # Check if vault already exists
    if [ -d "$vault_dir" ]; then
        print_warning "Vault directory already exists: $vault_dir"
        if confirm_action "Delete existing vault and continue?"; then
            rm -rf "$vault_dir"
        else
            return 1
        fi
    fi

    echo

    # ─────────────────────────────────────────────────────────────────────
    # STEP 1: Compress
    # ─────────────────────────────────────────────────────────────────────
    print_step "1/4" "Compressing folder..."

    if ! tar --use-compress-program=pigz -cf "$archive_file" -C "$parent_dir" "$folder_name"; then
        print_error "Compression failed"
        return 1
    fi

    local archive_size=$(du -h "$archive_file" | cut -f1)
    print_success "Compressed: $archive_file ($archive_size)"

    # ─────────────────────────────────────────────────────────────────────
    # STEP 2: Encrypt
    # ─────────────────────────────────────────────────────────────────────
    print_step "2/4" "Encrypting archive..."
    echo
    echo -e "${YELLOW}Enter a strong password for encryption.${NC}"
    echo -e "${YELLOW}You will need this password to restore the vault later.${NC}"
    echo

    if ! openssl enc -"$CIPHER" -salt -pbkdf2 -iter "$PBKDF2_ITERATIONS" \
        -in "$archive_file" -out "$encrypted_file"; then
        print_error "Encryption failed"
        secure_delete "$archive_file"
        return 1
    fi

    local encrypted_size=$(du -h "$encrypted_file" | cut -f1)
    print_success "Encrypted: $encrypted_file ($encrypted_size)"

    # ─────────────────────────────────────────────────────────────────────
    # STEP 3: Cleanup unencrypted archive
    # ─────────────────────────────────────────────────────────────────────
    print_step "3/4" "Securing intermediate files..."

    secure_delete "$archive_file"
    print_success "Removed unencrypted archive"

    # ─────────────────────────────────────────────────────────────────────
    # STEP 4: Create vault with Git LFS
    # ─────────────────────────────────────────────────────────────────────
    print_step "4/4" "Creating Git LFS vault..."

    mkdir -p "$vault_dir"
    mv "$encrypted_file" "$vault_dir/"

    cd "$vault_dir"
    git init --quiet
    git lfs install --local >/dev/null 2>&1

    # .gitattributes - ONLY track encrypted files with LFS
    cat > .gitattributes << 'EOF'
*.enc filter=lfs diff=lfs merge=lfs -text
*.tar.gz.enc filter=lfs diff=lfs merge=lfs -text
EOF

    # .gitignore
    cat > .gitignore << 'EOF'
# Unencrypted files (should never exist in vault)
*.tar.gz
*.tar

# OS files
.DS_Store
Thumbs.db
Desktop.ini

# Temporary files
*.tmp
*.temp
EOF

    # Vault info file
    cat > VAULT_INFO.md << EOF
# Vaulter V2 - Encrypted Backup

## Vault Details
| Property | Value |
|----------|-------|
| Original folder | \`$folder_name\` |
| Created | $(date -u +"%Y-%m-%d %H:%M:%S UTC") |
| Encryption | AES-256-CBC |
| Key derivation | PBKDF2 with $PBKDF2_ITERATIONS iterations |
| Vaulter version | $VERSION |

## How to Restore

### Option 1: Using Vaulter (Recommended)
\`\`\`bash
# Clone this repository
git clone <repo-url> && cd <repo-name>
git lfs pull

# Run vaulter and choose "DE-VAULT"
./vaulter.sh
# Select option 2, enter the vault path, and your password
\`\`\`

### Option 2: Manual Restoration
\`\`\`bash
# Clone and pull LFS files
git clone <repo-url> && cd <repo-name>
git lfs pull

# Decrypt (you'll be prompted for password)
openssl enc -d -aes-256-cbc -salt -pbkdf2 -iter $PBKDF2_ITERATIONS \\
    -in ${folder_name}.tar.gz.enc -out ${folder_name}.tar.gz

# Decompress
tar -xzf ${folder_name}.tar.gz

# Cleanup
rm ${folder_name}.tar.gz
\`\`\`

## Security Notes
- Only the encrypted \`.enc\` file is stored in this repository
- The encryption password is NOT stored anywhere
- Without the password, the data cannot be recovered
- Keep your password safe!
EOF

    git add .
    git commit -m "Vault: $folder_name ($(date +%Y-%m-%d))" --quiet
    git branch -M main

    print_success "Git LFS vault created"

    echo
    echo "┌─────────────────────────────────────────────────────────────────┐"
    echo "│ VAULT CREATED SUCCESSFULLY                                      │"
    echo "├─────────────────────────────────────────────────────────────────┤"
    printf "│ %-63s │\n" "Location: $vault_dir"
    echo "├─────────────────────────────────────────────────────────────────┤"
    echo "│ Contents:                                                       │"
    for f in "$vault_dir"/*; do
        printf "│   %-61s │\n" "$(basename "$f")"
    done
    echo "└─────────────────────────────────────────────────────────────────┘"
    echo

    # Ask about pushing to remote
    if confirm_action "Push vault to a remote repository?"; then
        echo
        read -r -p "Enter remote URL (GitHub/GitLab): " remote_url

        if [ -n "$remote_url" ]; then
            git remote add origin "$remote_url"

            print_info "Pushing to remote..."
            if git push -u origin main; then
                print_success "Pushed to: $remote_url"
            else
                print_error "Push failed. You can try again later with option [7]"
            fi
        fi
    fi

    echo
    print_warning "IMPORTANT: Your original folder still exists at:"
    echo "           $source_folder"
    echo

    if confirm_action "Delete the original folder now?"; then
        rm -rf "$source_folder"
        print_success "Original folder deleted"
    else
        print_info "Original folder kept. Delete it manually when ready."
    fi

    cd - > /dev/null 2>&1 || true

    echo
    print_success "VAULT COMPLETE!"
}

# ============================================================================
# DE-VAULT WORKFLOW
# ============================================================================

devault_folder() {
    echo
    echo -e "${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}                       DE-VAULT (RESTORE)                        ${NC}"
    echo -e "${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo
    echo "This will restore your folder from an encrypted vault:"
    echo "  1. Decrypt the archive"
    echo "  2. Decompress to original folder"
    echo "  3. Clean up intermediate files"
    echo

    local vault_dir
    local from_remote=false

    echo "Restore from:"
    echo "  [1] Local vault directory"
    echo "  [2] Remote repository (clone first)"
    echo
    read -r -p "Choice [1/2]: " source_type

    if [ "$source_type" = "2" ]; then
        from_remote=true
        echo
        read -r -p "Enter remote repository URL: " remote_url
        read -r -p "Enter local directory to clone into: " clone_dir

        echo
        print_info "Cloning repository..."

        if ! git clone "$remote_url" "$clone_dir"; then
            print_error "Clone failed"
            return 1
        fi

        cd "$clone_dir"

        print_info "Pulling LFS files..."
        git lfs pull

        vault_dir="$(pwd)"
        cd - > /dev/null
    else
        vault_dir=$(get_folder_path "Enter the vault directory path")
    fi

    # Validate
    if [ ! -d "$vault_dir" ]; then
        print_error "Directory does not exist: $vault_dir"
        return 1
    fi

    vault_dir="$(cd "$vault_dir" && pwd)"

    # Find encrypted file
    local enc_files=()
    while IFS= read -r -d '' f; do
        enc_files+=("$f")
    done < <(find "$vault_dir" -maxdepth 1 -name "*.enc" -print0 2>/dev/null)

    local encrypted_file

    if [ ${#enc_files[@]} -eq 0 ]; then
        print_error "No .enc files found in: $vault_dir"
        return 1
    elif [ ${#enc_files[@]} -eq 1 ]; then
        encrypted_file="${enc_files[0]}"
    else
        echo
        echo "Multiple .enc files found:"
        for i in "${!enc_files[@]}"; do
            echo "  [$((i+1))] $(basename "${enc_files[$i]}")"
        done
        echo
        read -r -p "Select file [1-${#enc_files[@]}]: " selection
        encrypted_file="${enc_files[$((selection-1))]}"
    fi

    if [ ! -f "$encrypted_file" ]; then
        print_error "File not found: $encrypted_file"
        return 1
    fi

    # Determine output paths
    local enc_basename=$(basename "$encrypted_file")
    local folder_name="${enc_basename%.tar.gz.enc}"

    # Handle different naming conventions
    if [[ "$enc_basename" == *.enc ]] && [[ "$enc_basename" != *.tar.gz.enc ]]; then
        folder_name="${enc_basename%.enc}"
        folder_name="${folder_name%.tar.gz}"
    fi

    local parent_dir=$(dirname "$vault_dir")
    local decrypted_file="${vault_dir}/${folder_name}.tar.gz"
    local restore_dir="${parent_dir}/${folder_name}"

    echo
    echo "┌─────────────────────────────────────────────────────────────────┐"
    echo "│ RESTORE SUMMARY                                                 │"
    echo "├─────────────────────────────────────────────────────────────────┤"
    printf "│ %-63s │\n" "Encrypted: $(basename "$encrypted_file")"
    printf "│ %-63s │\n" "Restore to: $restore_dir"
    echo "└─────────────────────────────────────────────────────────────────┘"
    echo

    if ! confirm_action "Proceed with restoration?"; then
        print_info "Cancelled"
        return 0
    fi

    # Check if restore dir exists
    if [ -d "$restore_dir" ]; then
        print_warning "Restore directory already exists: $restore_dir"
        if confirm_action "Delete and continue?"; then
            rm -rf "$restore_dir"
        else
            return 1
        fi
    fi

    echo

    # ─────────────────────────────────────────────────────────────────────
    # STEP 1: Decrypt
    # ─────────────────────────────────────────────────────────────────────
    print_step "1/3" "Decrypting archive..."
    echo
    echo -e "${YELLOW}Enter your decryption password:${NC}"
    echo

    if ! openssl enc -d -"$CIPHER" -salt -pbkdf2 -iter "$PBKDF2_ITERATIONS" \
        -in "$encrypted_file" -out "$decrypted_file" 2>/dev/null; then
        print_error "Decryption failed - incorrect password or corrupted file"
        secure_delete "$decrypted_file"
        return 1
    fi

    print_success "Decrypted successfully"

    # ─────────────────────────────────────────────────────────────────────
    # STEP 2: Decompress
    # ─────────────────────────────────────────────────────────────────────
    print_step "2/3" "Decompressing archive..."

    if ! tar -xzf "$decrypted_file" -C "$parent_dir"; then
        print_error "Decompression failed"
        secure_delete "$decrypted_file"
        return 1
    fi

    print_success "Decompressed successfully"

    # ─────────────────────────────────────────────────────────────────────
    # STEP 3: Cleanup
    # ─────────────────────────────────────────────────────────────────────
    print_step "3/3" "Cleaning up intermediate files..."

    secure_delete "$decrypted_file"
    print_success "Removed decrypted archive"

    echo
    echo "┌─────────────────────────────────────────────────────────────────┐"
    echo "│ RESTORE COMPLETE                                                │"
    echo "├─────────────────────────────────────────────────────────────────┤"
    printf "│ %-63s │\n" "Restored folder: $restore_dir"
    echo "└─────────────────────────────────────────────────────────────────┘"
    echo

    # Ask about deleting vault
    if confirm_action "Delete the vault directory?"; then
        rm -rf "$vault_dir"
        print_success "Vault directory deleted"
    else
        print_info "Vault kept at: $vault_dir"
    fi

    echo
    print_success "DE-VAULT COMPLETE!"
}

# ============================================================================
# INDIVIDUAL OPERATIONS
# ============================================================================

compress_only() {
    echo
    print_info "COMPRESS ONLY"
    echo

    local folder
    folder=$(get_folder_path "Enter folder path to compress")

    if [ ! -d "$folder" ]; then
        print_error "Folder does not exist: $folder"
        return 1
    fi

    folder="${folder%/}"
    folder="$(cd "$folder" && pwd)"

    local folder_name=$(basename "$folder")
    local parent_dir=$(dirname "$folder")
    local output="${parent_dir}/${folder_name}.tar.gz"

    print_info "Compressing..."

    if tar --use-compress-program=pigz -cf "$output" -C "$parent_dir" "$folder_name"; then
        local size=$(du -h "$output" | cut -f1)
        print_success "Created: $output ($size)"
    else
        print_error "Compression failed"
        return 1
    fi
}

encrypt_only() {
    echo
    print_info "ENCRYPT ONLY"
    echo

    local file
    read -r -p "Enter file path to encrypt: " file

    if [ ! -f "$file" ]; then
        print_error "File does not exist: $file"
        return 1
    fi

    local output="${file}.enc"

    echo
    echo "Encryption: AES-256-CBC with PBKDF2 ($PBKDF2_ITERATIONS iterations)"
    echo

    if openssl enc -"$CIPHER" -salt -pbkdf2 -iter "$PBKDF2_ITERATIONS" \
        -in "$file" -out "$output"; then
        local size=$(du -h "$output" | cut -f1)
        print_success "Created: $output ($size)"

        echo
        if confirm_action "Delete original unencrypted file?"; then
            secure_delete "$file"
            print_success "Original file securely deleted"
        fi
    else
        print_error "Encryption failed"
        return 1
    fi
}

decrypt_only() {
    echo
    print_info "DECRYPT ONLY"
    echo

    local file
    read -r -p "Enter .enc file path to decrypt: " file

    if [ ! -f "$file" ]; then
        print_error "File does not exist: $file"
        return 1
    fi

    local output="${file%.enc}"

    echo
    print_info "Decrypting..."
    echo

    if openssl enc -d -"$CIPHER" -salt -pbkdf2 -iter "$PBKDF2_ITERATIONS" \
        -in "$file" -out "$output" 2>/dev/null; then
        local size=$(du -h "$output" | cut -f1)
        print_success "Created: $output ($size)"
    else
        print_error "Decryption failed - incorrect password or corrupted file"
        secure_delete "$output"
        return 1
    fi
}

decompress_only() {
    echo
    print_info "DECOMPRESS ONLY"
    echo

    local file
    read -r -p "Enter .tar.gz file path to decompress: " file

    if [ ! -f "$file" ]; then
        print_error "File does not exist: $file"
        return 1
    fi

    local parent_dir=$(dirname "$file")

    print_info "Decompressing..."

    if tar -xzf "$file" -C "$parent_dir"; then
        print_success "Decompressed to: $parent_dir/"
    else
        print_error "Decompression failed"
        return 1
    fi
}

# ============================================================================
# GIT OPERATIONS
# ============================================================================

push_vault() {
    echo
    print_info "PUSH VAULT TO REMOTE"
    echo

    local vault_dir
    vault_dir=$(get_folder_path "Enter vault directory path")

    if [ ! -d "$vault_dir/.git" ]; then
        print_error "Not a git repository: $vault_dir"
        return 1
    fi

    cd "$vault_dir"

    read -r -p "Enter remote URL: " remote_url

    if [ -z "$remote_url" ]; then
        print_error "No URL provided"
        cd - > /dev/null
        return 1
    fi

    # Check if origin exists
    if git remote get-url origin >/dev/null 2>&1; then
        print_info "Updating existing remote..."
        git remote set-url origin "$remote_url"
    else
        git remote add origin "$remote_url"
    fi

    print_info "Pushing..."

    if git push -u origin main; then
        print_success "Pushed to: $remote_url"
    else
        print_error "Push failed"
    fi

    cd - > /dev/null
}

pull_vault() {
    echo
    print_info "PULL VAULT FROM REMOTE"
    echo

    read -r -p "Enter remote repository URL: " remote_url
    read -r -p "Enter local directory to clone into: " clone_dir

    if [ -z "$remote_url" ] || [ -z "$clone_dir" ]; then
        print_error "URL and directory are required"
        return 1
    fi

    print_info "Cloning..."

    if ! git clone "$remote_url" "$clone_dir"; then
        print_error "Clone failed"
        return 1
    fi

    cd "$clone_dir"

    print_info "Pulling LFS files..."
    git lfs pull

    print_success "Vault cloned to: $clone_dir"

    echo
    echo "Contents:"
    ls -la

    cd - > /dev/null
}

# ============================================================================
# SETTINGS
# ============================================================================

set_working_path() {
    echo
    if [ -n "$working_path" ]; then
        echo "Current path: $working_path"
        echo
    fi

    read -r -p "Enter new working path (or blank to clear): " new_path

    if [ -n "$new_path" ]; then
        if [ -d "$new_path" ]; then
            working_path="$(cd "$new_path" && pwd)"
            print_success "Working path set to: $working_path"
        else
            print_error "Directory does not exist: $new_path"
        fi
    else
        working_path=""
        print_info "Working path cleared"
    fi
}

# ============================================================================
# HELP
# ============================================================================

show_help() {
    echo
    echo -e "${BOLD}VAULTER V2 - HELP${NC}"
    echo "═══════════════════════════════════════════════════════════════════"
    echo
    echo -e "${BOLD}PURPOSE${NC}"
    echo "  Create encrypted backups of folders and store them securely"
    echo "  in Git LFS repositories for remote backup."
    echo
    echo -e "${BOLD}SECURITY${NC}"
    echo "  • Encryption: AES-256-CBC (military-grade)"
    echo "  • Key derivation: PBKDF2 with $PBKDF2_ITERATIONS iterations"
    echo "  • Only encrypted files are pushed to remote"
    echo "  • Intermediate unencrypted files are automatically deleted"
    echo "  • Password is never stored or transmitted"
    echo
    echo -e "${BOLD}WORKFLOW${NC}"
    echo
    echo "  VAULT (backup):"
    echo "    folder → compress → encrypt → git lfs → push"
    echo
    echo "  DE-VAULT (restore):"
    echo "    pull → decrypt → decompress → folder"
    echo
    echo -e "${BOLD}REQUIREMENTS${NC}"
    echo "  • pigz    - parallel gzip compression"
    echo "  • openssl - encryption/decryption"
    echo "  • git     - version control"
    echo "  • git-lfs - large file storage"
    echo
    echo -e "${BOLD}INSTALLATION${NC}"
    echo "  macOS:  brew install pigz openssl git git-lfs"
    echo "  Linux:  sudo apt install pigz openssl git git-lfs"
    echo
    echo "═══════════════════════════════════════════════════════════════════"
}

# ============================================================================
# MAIN MENU
# ============================================================================

main() {
    print_header

    if ! check_prerequisites; then
        echo
        echo "Please install the missing tools and try again."
        exit 1
    fi

    while true; do
        echo
        echo "┌─────────────────────────────────────────────────────────────────┐"
        echo "│                         MAIN MENU                               │"
        echo "├─────────────────────────────────────────────────────────────────┤"
        echo "│  [1] VAULT        - Create encrypted backup of a folder        │"
        echo "│  [2] DE-VAULT     - Restore folder from encrypted backup       │"
        echo "├─────────────────────────────────────────────────────────────────┤"
        echo "│  [3] Compress     - Compress folder only                       │"
        echo "│  [4] Encrypt      - Encrypt file only                          │"
        echo "│  [5] Decrypt      - Decrypt file only                          │"
        echo "│  [6] Decompress   - Decompress archive only                    │"
        echo "├─────────────────────────────────────────────────────────────────┤"
        echo "│  [7] Push         - Push vault to remote                       │"
        echo "│  [8] Pull         - Pull vault from remote                     │"
        echo "├─────────────────────────────────────────────────────────────────┤"
        echo "│  [0] Set Path     - Set working directory                      │"
        echo "│  [h] Help         - Show documentation                         │"
        echo "│  [q] Quit         - Exit vaulter                               │"
        echo "└─────────────────────────────────────────────────────────────────┘"

        if [ -n "$working_path" ]; then
            echo -e "  ${BLUE}Working path: $working_path${NC}"
        fi

        echo
        read -r -p "  Enter choice: " choice

        case $choice in
            1) vault_folder ;;
            2) devault_folder ;;
            3) compress_only ;;
            4) encrypt_only ;;
            5) decrypt_only ;;
            6) decompress_only ;;
            7) push_vault ;;
            8) pull_vault ;;
            0) set_working_path ;;
            h|H) show_help ;;
            q|Q)
                echo
                echo "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid choice"
                ;;
        esac
    done
}

# Run
main "$@"
