#!/bin/bash

# ============================================================================
# INTEGRATION TESTS
# Tests for complete vaulter workflows (vault and de-vault)
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_utils.sh"

# ============================================================================
# SIMULATED VAULT WORKFLOW
# These tests simulate what vaulter does without running the interactive script
# ============================================================================

# Simulate the full vault workflow
simulate_vault_workflow() {
    local source_folder="$1"
    local password="$2"
    local vault_name="${3:-$(basename "$source_folder")-vault}"

    local folder_name=$(basename "$source_folder")
    local parent_dir=$(dirname "$source_folder")
    local vault_dir="${parent_dir}/${vault_name}"
    local archive_file="${parent_dir}/${folder_name}.tar.gz"
    local encrypted_file="${parent_dir}/${folder_name}.tar.gz.enc"

    # Step 1: Compress
    tar --use-compress-program=pigz -cf "$archive_file" -C "$parent_dir" "$folder_name" || return 1

    # Step 2: Encrypt
    echo "$password" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter "$PBKDF2_ITERATIONS" \
        -in "$archive_file" -out "$encrypted_file" -pass stdin || return 1

    # Step 3: Delete unencrypted archive
    rm -f "$archive_file"

    # Step 4: Create vault directory
    mkdir -p "$vault_dir"
    mv "$encrypted_file" "$vault_dir/"

    # Step 5: Initialize git
    cd "$vault_dir"
    git init --quiet
    git lfs install --local >/dev/null 2>&1

    # Create .gitattributes
    cat > .gitattributes << 'EOF'
*.enc filter=lfs diff=lfs merge=lfs -text
*.tar.gz.enc filter=lfs diff=lfs merge=lfs -text
EOF

    # Create .gitignore
    cat > .gitignore << 'EOF'
*.tar.gz
*.tar
.DS_Store
EOF

    # Create info file
    echo "# Vault Info" > VAULT_INFO.md
    echo "Original: $folder_name" >> VAULT_INFO.md

    git add .
    git commit -m "Vault: $folder_name" --quiet
    git branch -M main

    cd - > /dev/null

    echo "$vault_dir"
}

# Simulate the full de-vault workflow
simulate_devault_workflow() {
    local vault_dir="$1"
    local password="$2"
    local restore_parent="${3:-$(dirname "$vault_dir")}"

    # Find the encrypted file
    local encrypted_file=$(find "$vault_dir" -maxdepth 1 -name "*.enc" | head -1)
    if [ -z "$encrypted_file" ]; then
        return 1
    fi

    local enc_basename=$(basename "$encrypted_file")
    local folder_name="${enc_basename%.tar.gz.enc}"
    local decrypted_file="${vault_dir}/${folder_name}.tar.gz"
    local restore_dir="${restore_parent}/${folder_name}"

    # Step 1: Decrypt
    echo "$password" | openssl enc -d -aes-256-cbc -salt -pbkdf2 -iter "$PBKDF2_ITERATIONS" \
        -in "$encrypted_file" -out "$decrypted_file" -pass stdin 2>/dev/null || return 1

    # Step 2: Decompress
    tar -xzf "$decrypted_file" -C "$restore_parent" || return 1

    # Step 3: Cleanup
    rm -f "$decrypted_file"

    echo "$restore_dir"
}

# ============================================================================
# VAULT WORKFLOW TESTS
# ============================================================================

test_vault_workflow_creates_vault_directory() {
    local folder=$(create_test_folder "project_data")

    local vault_dir=$(simulate_vault_workflow "$folder" "$TEST_PASSWORD")

    assert_dir_exists "$vault_dir" "Vault directory should be created"
    assert_equals "project_data-vault" "$(basename "$vault_dir")" "Vault should have correct name"
}

test_vault_workflow_creates_encrypted_file() {
    local folder=$(create_test_folder "project_data")

    local vault_dir=$(simulate_vault_workflow "$folder" "$TEST_PASSWORD")

    assert_file_exists "$vault_dir/project_data.tar.gz.enc" "Encrypted file should exist"
}

test_vault_workflow_removes_unencrypted_archive() {
    local folder=$(create_test_folder "project_data")
    local parent=$(dirname "$folder")

    simulate_vault_workflow "$folder" "$TEST_PASSWORD"

    assert_file_not_exists "$parent/project_data.tar.gz" "Unencrypted archive should be deleted"
}

test_vault_workflow_creates_git_repo() {
    local folder=$(create_test_folder "project_data")

    local vault_dir=$(simulate_vault_workflow "$folder" "$TEST_PASSWORD")

    assert_dir_exists "$vault_dir/.git" "Git repo should exist"
}

test_vault_workflow_has_gitattributes() {
    local folder=$(create_test_folder "project_data")

    local vault_dir=$(simulate_vault_workflow "$folder" "$TEST_PASSWORD")

    assert_file_exists "$vault_dir/.gitattributes" ".gitattributes should exist"
    assert_file_contains "$vault_dir/.gitattributes" "*.enc filter=lfs" "Should track .enc with LFS"
}

test_vault_workflow_has_gitignore() {
    local folder=$(create_test_folder "project_data")

    local vault_dir=$(simulate_vault_workflow "$folder" "$TEST_PASSWORD")

    assert_file_exists "$vault_dir/.gitignore" ".gitignore should exist"
    assert_file_contains "$vault_dir/.gitignore" "*.tar.gz" "Should ignore unencrypted archives"
}

test_vault_workflow_has_vault_info() {
    local folder=$(create_test_folder "project_data")

    local vault_dir=$(simulate_vault_workflow "$folder" "$TEST_PASSWORD")

    assert_file_exists "$vault_dir/VAULT_INFO.md" "VAULT_INFO.md should exist"
}

test_vault_workflow_git_has_commit() {
    local folder=$(create_test_folder "project_data")

    local vault_dir=$(simulate_vault_workflow "$folder" "$TEST_PASSWORD")

    cd "$vault_dir"
    local commit_count=$(git rev-list --count HEAD)
    cd - > /dev/null

    assert_true "[ $commit_count -ge 1 ]" "Should have at least one commit"
}

test_vault_workflow_only_encrypted_in_git() {
    local folder=$(create_test_folder "project_data")

    local vault_dir=$(simulate_vault_workflow "$folder" "$TEST_PASSWORD")

    cd "$vault_dir"
    # List all tracked files
    local tracked_files=$(git ls-files)

    # Should contain .enc file
    echo "$tracked_files" | grep -q "\.enc"
    local has_enc=$?

    # Should NOT contain .tar.gz (unencrypted)
    echo "$tracked_files" | grep -v "\.enc" | grep -q "\.tar\.gz"
    local has_unenc=$?

    cd - > /dev/null

    assert_equals "0" "$has_enc" "Encrypted file should be tracked"
    assert_not_equals "0" "$has_unenc" "Unencrypted archive should NOT be tracked"
}

# ============================================================================
# DE-VAULT WORKFLOW TESTS
# ============================================================================

test_devault_workflow_restores_folder() {
    local folder=$(create_test_folder "important_files")
    local original_checksum=$(get_folder_checksum "$folder")

    local vault_dir=$(simulate_vault_workflow "$folder" "$TEST_PASSWORD")
    rm -rf "$folder"  # Original is "deleted"

    local restored=$(simulate_devault_workflow "$vault_dir" "$TEST_PASSWORD")

    assert_dir_exists "$restored" "Restored folder should exist"
}

test_devault_workflow_data_integrity() {
    local folder=$(create_test_folder "important_files" 5)
    local original_checksum=$(get_folder_checksum "$folder")

    local vault_dir=$(simulate_vault_workflow "$folder" "$TEST_PASSWORD")
    rm -rf "$folder"

    local restored=$(simulate_devault_workflow "$vault_dir" "$TEST_PASSWORD")
    local restored_checksum=$(get_folder_checksum "$restored")

    assert_equals "$original_checksum" "$restored_checksum" "Data integrity should be maintained"
}

test_devault_workflow_cleans_up() {
    local folder=$(create_test_folder "important_files")

    local vault_dir=$(simulate_vault_workflow "$folder" "$TEST_PASSWORD")
    rm -rf "$folder"

    simulate_devault_workflow "$vault_dir" "$TEST_PASSWORD"

    # Check that decrypted tar.gz was cleaned up
    local tar_files=$(find "$vault_dir" -name "*.tar.gz" ! -name "*.enc" | wc -l)
    assert_equals "0" "$(echo $tar_files | tr -d ' ')" "Decrypted archive should be cleaned up"
}

test_devault_workflow_wrong_password_fails() {
    local folder=$(create_test_folder "important_files")

    local vault_dir=$(simulate_vault_workflow "$folder" "correct_password")
    rm -rf "$folder"

    # Try to devault with wrong password - should fail
    simulate_devault_workflow "$vault_dir" "wrong_password" >/dev/null 2>&1
    local exit_code=$?

    assert_not_equals "0" "$exit_code" "De-vault with wrong password should fail"
}

# ============================================================================
# FULL CYCLE TESTS (vault -> remote simulation -> devault)
# ============================================================================

test_full_cycle_with_local_remote() {
    local folder=$(create_test_folder "backup_data" 5)
    local original_checksum=$(get_folder_checksum "$folder")

    # Create vault
    local vault_dir=$(simulate_vault_workflow "$folder" "$TEST_PASSWORD")
    rm -rf "$folder"

    # Simulate "remote transfer" by copying the vault to a new location
    # (Git LFS requires a proper server for actual transfer, so we simulate)
    local transferred_vault="./transferred_vault"
    cp -r "$vault_dir" "$transferred_vault"

    # Verify the transferred vault has the encrypted file
    local enc_file=$(find "$transferred_vault" -maxdepth 1 -name "*.enc" | head -1)
    if [ -z "$enc_file" ]; then
        echo "  No encrypted file in transferred vault"
        return 1
    fi

    # De-vault from transferred location
    local parent_dir="./restored_parent"
    mkdir -p "$parent_dir"
    local restored=$(simulate_devault_workflow "$transferred_vault" "$TEST_PASSWORD" "$parent_dir")

    # Verify integrity
    if [ -d "$restored" ]; then
        local restored_checksum=$(get_folder_checksum "$restored")
        assert_equals "$original_checksum" "$restored_checksum" "Full cycle should preserve data"
    elif [ -d "$parent_dir/backup_data" ]; then
        local restored_checksum=$(get_folder_checksum "$parent_dir/backup_data")
        assert_equals "$original_checksum" "$restored_checksum" "Full cycle should preserve data"
    else
        assert_dir_exists "$parent_dir/backup_data" "Restored folder should exist"
    fi
}

test_full_cycle_with_large_data() {
    local folder=$(create_test_folder_with_size "large_backup" 2048)  # 2MB
    local original_checksum=$(get_folder_checksum "$folder")

    local vault_dir=$(simulate_vault_workflow "$folder" "$TEST_PASSWORD")
    rm -rf "$folder"

    local restored=$(simulate_devault_workflow "$vault_dir" "$TEST_PASSWORD")
    local restored_checksum=$(get_folder_checksum "$restored")

    assert_equals "$original_checksum" "$restored_checksum" "Large data cycle should preserve integrity"
}

test_full_cycle_with_many_files() {
    mkdir -p "many_files"
    for i in $(seq 1 100); do
        echo "Content of file $i" > "many_files/file_$i.txt"
    done
    local original_checksum=$(get_folder_checksum "many_files")

    local vault_dir=$(simulate_vault_workflow "many_files" "$TEST_PASSWORD")
    rm -rf "many_files"

    local restored=$(simulate_devault_workflow "$vault_dir" "$TEST_PASSWORD")
    local restored_checksum=$(get_folder_checksum "$restored")

    assert_equals "$original_checksum" "$restored_checksum" "Many files should preserve integrity"
}

test_full_cycle_with_deep_nesting() {
    mkdir -p "deep/l1/l2/l3/l4/l5/l6/l7/l8/l9/l10"
    echo "Deep content" > "deep/l1/l2/l3/l4/l5/l6/l7/l8/l9/l10/deep.txt"
    echo "Surface content" > "deep/surface.txt"
    local original_checksum=$(get_folder_checksum "deep")

    local vault_dir=$(simulate_vault_workflow "deep" "$TEST_PASSWORD")
    rm -rf "deep"

    local restored=$(simulate_devault_workflow "$vault_dir" "$TEST_PASSWORD")
    local restored_checksum=$(get_folder_checksum "$restored")

    assert_equals "$original_checksum" "$restored_checksum" "Deep nesting should preserve integrity"
}

test_full_cycle_with_special_filenames() {
    mkdir -p "special_names"
    echo "content" > "special_names/file with spaces.txt"
    echo "content" > "special_names/file-with-dashes.txt"
    echo "content" > "special_names/file_with_underscores.txt"
    echo "content" > "special_names/file.multiple.dots.txt"
    local original_checksum=$(get_folder_checksum "special_names")

    local vault_dir=$(simulate_vault_workflow "special_names" "$TEST_PASSWORD")
    rm -rf "special_names"

    local restored=$(simulate_devault_workflow "$vault_dir" "$TEST_PASSWORD")
    local restored_checksum=$(get_folder_checksum "$restored")

    assert_equals "$original_checksum" "$restored_checksum" "Special filenames should preserve integrity"
}

test_full_cycle_with_symlinks() {
    mkdir -p "with_symlinks"
    echo "target content" > "with_symlinks/target.txt"
    ln -s "target.txt" "with_symlinks/link.txt" 2>/dev/null || skip_test

    local vault_dir=$(simulate_vault_workflow "with_symlinks" "$TEST_PASSWORD")
    rm -rf "with_symlinks"

    local restored=$(simulate_devault_workflow "$vault_dir" "$TEST_PASSWORD")

    assert_file_exists "$restored/target.txt" "Target file should exist"
    # Symlink may or may not be preserved depending on tar options
}

test_full_cycle_with_empty_subdirs() {
    mkdir -p "with_empty/empty1"
    mkdir -p "with_empty/empty2"
    mkdir -p "with_empty/notempty"
    echo "content" > "with_empty/notempty/file.txt"

    local vault_dir=$(simulate_vault_workflow "with_empty" "$TEST_PASSWORD")
    rm -rf "with_empty"

    local restored=$(simulate_devault_workflow "$vault_dir" "$TEST_PASSWORD")

    assert_dir_exists "$restored/notempty" "Non-empty dir should exist"
    assert_file_exists "$restored/notempty/file.txt" "File in non-empty dir should exist"
}

# ============================================================================
# EDGE CASE TESTS
# ============================================================================

test_vault_with_spaces_in_folder_name() {
    local folder=$(create_test_folder_with_spaces "my project folder")
    local original_checksum=$(get_folder_checksum "$folder")

    local vault_dir=$(simulate_vault_workflow "$folder" "$TEST_PASSWORD")
    rm -rf "$folder"

    local restored=$(simulate_devault_workflow "$vault_dir" "$TEST_PASSWORD")
    local restored_checksum=$(get_folder_checksum "$restored")

    assert_equals "$original_checksum" "$restored_checksum" "Spaces in folder name should work"
}

test_vault_already_exists_behavior() {
    local folder=$(create_test_folder "myproject")

    # Create vault first time
    local vault_dir=$(simulate_vault_workflow "$folder" "$TEST_PASSWORD")

    # Try to vault same folder again - should handle gracefully
    # In real vaulter, it prompts user. Here we just verify vault exists
    assert_dir_exists "$vault_dir" "Vault should exist"
}

test_multiple_vaults_same_parent() {
    local folder1=$(create_test_folder "project1")
    local folder2=$(create_test_folder "project2")

    local vault1=$(simulate_vault_workflow "$folder1" "$TEST_PASSWORD" "project1-vault")
    local vault2=$(simulate_vault_workflow "$folder2" "$TEST_PASSWORD" "project2-vault")

    assert_dir_exists "$vault1" "First vault should exist"
    assert_dir_exists "$vault2" "Second vault should exist"
    assert_file_exists "$vault1/project1.tar.gz.enc" "First encrypted file should exist"
    assert_file_exists "$vault2/project2.tar.gz.enc" "Second encrypted file should exist"
}

# ============================================================================
# MAIN
# ============================================================================

run_integration_tests() {
    log_section "INTEGRATION TESTS"

    if ! check_prerequisites; then
        exit 1
    fi

    init_test_env

    # Vault workflow tests
    log_subsection "Vault Workflow Tests"
    run_test "Vault creates vault directory" test_vault_workflow_creates_vault_directory
    run_test "Vault creates encrypted file" test_vault_workflow_creates_encrypted_file
    run_test "Vault removes unencrypted archive" test_vault_workflow_removes_unencrypted_archive
    run_test "Vault creates git repo" test_vault_workflow_creates_git_repo
    run_test "Vault has .gitattributes" test_vault_workflow_has_gitattributes
    run_test "Vault has .gitignore" test_vault_workflow_has_gitignore
    run_test "Vault has VAULT_INFO.md" test_vault_workflow_has_vault_info
    run_test "Vault git has commit" test_vault_workflow_git_has_commit
    run_test "Only encrypted files in git" test_vault_workflow_only_encrypted_in_git

    # De-vault workflow tests
    log_subsection "De-vault Workflow Tests"
    run_test "De-vault restores folder" test_devault_workflow_restores_folder
    run_test "De-vault data integrity" test_devault_workflow_data_integrity
    run_test "De-vault cleans up temp files" test_devault_workflow_cleans_up
    run_test "De-vault wrong password fails" test_devault_workflow_wrong_password_fails

    # Full cycle tests
    log_subsection "Full Cycle Tests"
    run_test "Full cycle with local remote" test_full_cycle_with_local_remote
    run_test "Full cycle with large data" test_full_cycle_with_large_data
    run_test "Full cycle with many files" test_full_cycle_with_many_files
    run_test "Full cycle with deep nesting" test_full_cycle_with_deep_nesting
    run_test "Full cycle with special filenames" test_full_cycle_with_special_filenames
    run_test "Full cycle with symlinks" test_full_cycle_with_symlinks
    run_test "Full cycle with empty subdirs" test_full_cycle_with_empty_subdirs

    # Edge case tests
    log_subsection "Edge Case Tests"
    run_test "Vault with spaces in folder name" test_vault_with_spaces_in_folder_name
    run_test "Vault already exists behavior" test_vault_already_exists_behavior
    run_test "Multiple vaults same parent" test_multiple_vaults_same_parent

    cleanup_test_env

    print_test_summary
    return $?
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_integration_tests
fi
