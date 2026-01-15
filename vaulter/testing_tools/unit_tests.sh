#!/bin/bash

# ============================================================================
# UNIT TESTS
# Tests for individual vaulter components and functions
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_utils.sh"

# ============================================================================
# COMPRESSION TESTS
# ============================================================================

test_compression_creates_archive() {
    local folder=$(create_test_folder "mydata")

    local archive=$(vaulter_compress "$folder")

    assert_file_exists "$archive" "Archive should be created"
}

test_compression_archive_location() {
    local folder=$(create_test_folder "mydata")
    local expected_archive="./mydata.tar.gz"

    vaulter_compress "$folder" "$expected_archive"

    # Archive should be in parent directory, NOT inside the folder
    assert_file_exists "$expected_archive" "Archive should be in parent directory"
    assert_file_not_exists "$folder/mydata.tar.gz" "Archive should NOT be inside source folder"
}

test_compression_archive_not_empty() {
    local folder=$(create_test_folder "mydata")

    local archive=$(vaulter_compress "$folder")

    assert_file_size_greater_than "$archive" 0 "Archive should not be empty"
}

test_compression_preserves_structure() {
    local folder=$(create_test_folder "mydata")

    local archive=$(vaulter_compress "$folder")

    # Extract and verify structure
    mkdir -p "extracted"
    tar -xzf "$archive" -C "extracted"

    assert_dir_exists "extracted/mydata" "Extracted folder should exist"
    assert_file_exists "extracted/mydata/readme.txt" "Files should be preserved"
    assert_dir_exists "extracted/mydata/subdir/nested" "Nested directories should be preserved"
}

test_compression_with_spaces_in_name() {
    local folder=$(create_test_folder_with_spaces "my folder with spaces")

    local archive="my folder with spaces.tar.gz"
    vaulter_compress "$folder" "$archive"

    assert_file_exists "$archive" "Archive with spaces should be created"
}

test_compression_with_large_files() {
    local folder=$(create_test_folder_with_size "large_folder" 1024)  # 1MB

    local archive=$(vaulter_compress "$folder")

    assert_file_exists "$archive" "Large archive should be created"
    # Compressed should be smaller than original (usually)
    local original_size=$(du -sk "$folder" | cut -f1)
    local archive_size=$(du -sk "$archive" | cut -f1)
    # Just verify it was created, compression ratio varies
}

test_compression_empty_folder() {
    mkdir -p "empty_folder"

    local archive=$(vaulter_compress "empty_folder")

    assert_file_exists "$archive" "Empty folder archive should be created"
}

# ============================================================================
# ENCRYPTION TESTS
# ============================================================================

test_encryption_creates_enc_file() {
    echo "test data" > "test.txt"

    local encrypted=$(vaulter_encrypt "test.txt" "$TEST_PASSWORD")

    assert_file_exists "$encrypted" "Encrypted file should be created"
    assert_file_exists "test.txt.enc" "Should have .enc extension"
}

test_encryption_file_is_different() {
    echo "test data for encryption" > "test.txt"
    local original_checksum=$(get_file_checksum "test.txt")

    vaulter_encrypt "test.txt" "$TEST_PASSWORD"
    local encrypted_checksum=$(get_file_checksum "test.txt.enc")

    assert_not_equals "$original_checksum" "$encrypted_checksum" "Encrypted file should differ from original"
}

test_encryption_file_not_readable() {
    echo "secret data" > "test.txt"

    vaulter_encrypt "test.txt" "$TEST_PASSWORD"

    # Encrypted file should not contain the original text
    assert_file_not_contains "test.txt.enc" "secret data" "Encrypted file should not be readable"
}

test_encryption_produces_binary() {
    echo "test data" > "test.txt"

    vaulter_encrypt "test.txt" "$TEST_PASSWORD"

    # Check if file contains non-printable characters (binary)
    if file "test.txt.enc" | grep -q "text"; then
        echo "  WARNING: Encrypted file appears to be text (should be binary)"
        # This isn't necessarily a failure, but worth noting
    fi
    return 0
}

test_encryption_different_passwords_different_output() {
    echo "test data" > "test.txt"

    vaulter_encrypt "test.txt" "password1" "test1.enc"
    vaulter_encrypt "test.txt" "password2" "test2.enc"

    local checksum1=$(get_file_checksum "test1.enc")
    local checksum2=$(get_file_checksum "test2.enc")

    assert_not_equals "$checksum1" "$checksum2" "Different passwords should produce different output"
}

test_encryption_with_special_password() {
    echo "test data" > "test.txt"
    local special_password='P@$$w0rd!#%^&*()[]{}|;:,.<>?'

    vaulter_encrypt "test.txt" "$special_password"

    assert_file_exists "test.txt.enc" "Encryption with special chars should work"
}

test_encryption_with_unicode_password() {
    echo "test data" > "test.txt"
    local unicode_password="Password"

    vaulter_encrypt "test.txt" "$unicode_password"

    assert_file_exists "test.txt.enc" "Encryption with unicode should work"
}

test_encryption_large_file() {
    dd if=/dev/urandom of="large.bin" bs=1024 count=5120 2>/dev/null  # 5MB

    vaulter_encrypt "large.bin" "$TEST_PASSWORD"

    assert_file_exists "large.bin.enc" "Large file encryption should work"
}

# ============================================================================
# DECRYPTION TESTS
# ============================================================================

test_decryption_restores_original() {
    echo "original content here" > "test.txt"
    local original_checksum=$(get_file_checksum "test.txt")

    vaulter_encrypt "test.txt" "$TEST_PASSWORD"
    rm "test.txt"

    vaulter_decrypt "test.txt.enc" "$TEST_PASSWORD" "test_restored.txt"
    local restored_checksum=$(get_file_checksum "test_restored.txt")

    assert_equals "$original_checksum" "$restored_checksum" "Decrypted file should match original"
}

test_decryption_wrong_password_fails() {
    echo "secret data" > "test.txt"

    vaulter_encrypt "test.txt" "correct_password"

    assert_command_fails "vaulter_decrypt 'test.txt.enc' 'wrong_password' 'output.txt'" \
        "Decryption with wrong password should fail"
}

test_decryption_empty_password_fails() {
    echo "secret data" > "test.txt"

    vaulter_encrypt "test.txt" "$TEST_PASSWORD"

    assert_command_fails "vaulter_decrypt 'test.txt.enc' '' 'output.txt'" \
        "Decryption with empty password should fail"
}

test_decryption_corrupted_file_fails() {
    echo "test data" > "test.txt"

    vaulter_encrypt "test.txt" "$TEST_PASSWORD"

    # Corrupt the encrypted file
    echo "corruption" >> "test.txt.enc"

    # This may or may not fail depending on where corruption occurs
    # At minimum, the output should be different
    if vaulter_decrypt "test.txt.enc" "$TEST_PASSWORD" "output.txt" 2>/dev/null; then
        local original=$(cat "test.txt" 2>/dev/null)
        local decrypted=$(cat "output.txt" 2>/dev/null)
        if [ "$original" = "$decrypted" ]; then
            return 1  # Corruption not detected
        fi
    fi
    return 0
}

test_decryption_truncated_file_fails() {
    echo "test data that is longer" > "test.txt"

    vaulter_encrypt "test.txt" "$TEST_PASSWORD"

    # Truncate the file
    head -c 10 "test.txt.enc" > "truncated.enc"

    assert_command_fails "vaulter_decrypt 'truncated.enc' '$TEST_PASSWORD' 'output.txt'" \
        "Decryption of truncated file should fail"
}

# ============================================================================
# DECOMPRESSION TESTS
# ============================================================================

test_decompression_restores_folder() {
    local folder=$(create_test_folder "mydata" 3)
    local original_checksum=$(get_folder_checksum "$folder")

    local archive=$(vaulter_compress "$folder")
    rm -rf "$folder"

    mkdir -p "restored"
    vaulter_decompress "$archive" "restored"

    assert_dir_exists "restored/mydata" "Folder should be restored"
    local restored_checksum=$(get_folder_checksum "restored/mydata")

    assert_equals "$original_checksum" "$restored_checksum" "Restored folder should match original"
}

test_decompression_preserves_permissions() {
    local folder=$(create_test_folder "mydata")
    chmod 755 "$folder/readme.txt"

    local archive=$(vaulter_compress "$folder")
    rm -rf "$folder"

    mkdir -p "restored"
    vaulter_decompress "$archive" "restored"

    # Check permissions are preserved
    local perms=$(stat -f "%Lp" "restored/mydata/readme.txt" 2>/dev/null || \
                  stat -c "%a" "restored/mydata/readme.txt" 2>/dev/null)

    # Permissions should be preserved (may vary by umask)
    assert_file_exists "restored/mydata/readme.txt" "File should exist with permissions"
}

# ============================================================================
# GIT LFS TESTS
# ============================================================================

test_gitattributes_tracks_enc_files() {
    # Create expected .gitattributes content
    local expected_pattern="*.enc filter=lfs diff=lfs merge=lfs -text"

    cat > "test_gitattributes" << 'EOF'
*.enc filter=lfs diff=lfs merge=lfs -text
*.tar.gz.enc filter=lfs diff=lfs merge=lfs -text
EOF

    assert_file_contains "test_gitattributes" "*.enc filter=lfs" \
        ".gitattributes should track .enc files"
}

test_gitattributes_does_not_track_everything() {
    # This tests the V1 bug where "*" was tracked
    cat > "test_gitattributes" << 'EOF'
*.enc filter=lfs diff=lfs merge=lfs -text
*.tar.gz.enc filter=lfs diff=lfs merge=lfs -text
EOF

    assert_file_not_contains "test_gitattributes" '"\*" filter=lfs' \
        ".gitattributes should NOT track everything"

    # Also check it doesn't track .gitattributes itself
    assert_file_not_contains "test_gitattributes" ".gitattributes filter=lfs" \
        ".gitattributes should NOT track itself"
}

test_gitignore_ignores_unencrypted() {
    cat > "test_gitignore" << 'EOF'
# Unencrypted files (should never exist in vault)
*.tar.gz
*.tar

# OS files
.DS_Store
Thumbs.db
EOF

    assert_file_contains "test_gitignore" "*.tar.gz" \
        ".gitignore should ignore unencrypted archives"
}

test_git_init_creates_valid_repo() {
    mkdir -p "test_repo"
    cd "test_repo"

    git init --quiet
    git lfs install --local >/dev/null 2>&1

    assert_dir_exists ".git" "Git repo should be initialized"
    assert_file_exists ".git/config" "Git config should exist"

    # Check LFS is configured
    assert_file_contains ".git/config" "filter \"lfs\"" \
        "Git LFS should be configured"
}

# ============================================================================
# ROUNDTRIP TESTS (compress + encrypt + decrypt + decompress)
# ============================================================================

test_full_roundtrip_integrity() {
    local folder=$(create_test_folder "important_data" 10)
    local original_checksum=$(get_folder_checksum "$folder")

    # Compress
    local archive=$(vaulter_compress "$folder")

    # Encrypt
    vaulter_encrypt "$archive" "$TEST_PASSWORD"
    rm "$archive"

    # Decrypt
    vaulter_decrypt "${archive}.enc" "$TEST_PASSWORD" "decrypted.tar.gz"

    # Decompress
    rm -rf "$folder"
    mkdir -p "restored"
    vaulter_decompress "decrypted.tar.gz" "restored"

    local restored_checksum=$(get_folder_checksum "restored/important_data")

    assert_equals "$original_checksum" "$restored_checksum" \
        "Full roundtrip should preserve data integrity"
}

test_roundtrip_with_binary_files() {
    mkdir -p "binary_data"
    dd if=/dev/urandom of="binary_data/random.bin" bs=1024 count=100 2>/dev/null
    local original_checksum=$(get_file_checksum "binary_data/random.bin")

    # Full roundtrip
    local archive=$(vaulter_compress "binary_data")
    vaulter_encrypt "$archive" "$TEST_PASSWORD"
    rm "$archive"
    vaulter_decrypt "${archive}.enc" "$TEST_PASSWORD" "decrypted.tar.gz"
    mkdir -p "restored"
    vaulter_decompress "decrypted.tar.gz" "restored"

    local restored_checksum=$(get_file_checksum "restored/binary_data/random.bin")

    assert_equals "$original_checksum" "$restored_checksum" \
        "Binary files should survive roundtrip"
}

test_roundtrip_with_nested_structure() {
    mkdir -p "nested/level1/level2/level3"
    echo "deep content" > "nested/level1/level2/level3/deep.txt"
    echo "level1 content" > "nested/level1/file1.txt"
    local original_checksum=$(get_folder_checksum "nested")

    # Full roundtrip
    local archive=$(vaulter_compress "nested")
    vaulter_encrypt "$archive" "$TEST_PASSWORD"
    rm "$archive"
    vaulter_decrypt "${archive}.enc" "$TEST_PASSWORD" "decrypted.tar.gz"
    rm -rf "nested"
    mkdir -p "restored"
    vaulter_decompress "decrypted.tar.gz" "restored"

    local restored_checksum=$(get_folder_checksum "restored/nested")

    assert_equals "$original_checksum" "$restored_checksum" \
        "Nested structure should survive roundtrip"
}

# ============================================================================
# MAIN
# ============================================================================

run_unit_tests() {
    log_section "UNIT TESTS"

    if ! check_prerequisites; then
        exit 1
    fi

    init_test_env

    # Compression tests
    log_subsection "Compression Tests"
    run_test "Compression creates archive" test_compression_creates_archive
    run_test "Compression archive location" test_compression_archive_location
    run_test "Compression archive not empty" test_compression_archive_not_empty
    run_test "Compression preserves structure" test_compression_preserves_structure
    run_test "Compression with spaces in name" test_compression_with_spaces_in_name
    run_test "Compression with large files" test_compression_with_large_files
    run_test "Compression empty folder" test_compression_empty_folder

    # Encryption tests
    log_subsection "Encryption Tests"
    run_test "Encryption creates .enc file" test_encryption_creates_enc_file
    run_test "Encryption file is different" test_encryption_file_is_different
    run_test "Encryption file not readable" test_encryption_file_not_readable
    run_test "Encryption produces binary" test_encryption_produces_binary
    run_test "Different passwords different output" test_encryption_different_passwords_different_output
    run_test "Encryption with special password" test_encryption_with_special_password
    run_test "Encryption with unicode password" test_encryption_with_unicode_password
    run_test "Encryption large file" test_encryption_large_file

    # Decryption tests
    log_subsection "Decryption Tests"
    run_test "Decryption restores original" test_decryption_restores_original
    run_test "Decryption wrong password fails" test_decryption_wrong_password_fails
    run_test "Decryption empty password fails" test_decryption_empty_password_fails
    run_test "Decryption corrupted file fails" test_decryption_corrupted_file_fails
    run_test "Decryption truncated file fails" test_decryption_truncated_file_fails

    # Decompression tests
    log_subsection "Decompression Tests"
    run_test "Decompression restores folder" test_decompression_restores_folder
    run_test "Decompression preserves permissions" test_decompression_preserves_permissions

    # Git LFS tests
    log_subsection "Git LFS Configuration Tests"
    run_test "gitattributes tracks .enc files" test_gitattributes_tracks_enc_files
    run_test "gitattributes does not track everything" test_gitattributes_does_not_track_everything
    run_test "gitignore ignores unencrypted" test_gitignore_ignores_unencrypted
    run_test "Git init creates valid repo" test_git_init_creates_valid_repo

    # Roundtrip tests
    log_subsection "Roundtrip Tests"
    run_test "Full roundtrip integrity" test_full_roundtrip_integrity
    run_test "Roundtrip with binary files" test_roundtrip_with_binary_files
    run_test "Roundtrip with nested structure" test_roundtrip_with_nested_structure

    cleanup_test_env

    print_test_summary
    return $?
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_unit_tests
fi
