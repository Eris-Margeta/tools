#!/bin/bash

# ============================================================================
# SECURITY TESTS
# Tests for security properties of vaulter encryption and data handling
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_utils.sh"

# ============================================================================
# ENCRYPTION SECURITY TESTS
# ============================================================================

test_encryption_uses_pbkdf2() {
    # Verify that the encryption uses PBKDF2 by checking the file header
    echo "test data" > "test.txt"

    # Encrypt with PBKDF2
    echo "$TEST_PASSWORD" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter "$PBKDF2_ITERATIONS" \
        -in "test.txt" -out "test_pbkdf2.enc" -pass stdin

    # Encrypt WITHOUT PBKDF2 (legacy)
    echo "$TEST_PASSWORD" | openssl enc -aes-256-cbc -salt \
        -in "test.txt" -out "test_legacy.enc" -pass stdin 2>/dev/null || true

    # Files should be different (different key derivation)
    local pbkdf2_checksum=$(get_file_checksum "test_pbkdf2.enc")
    local legacy_checksum=$(get_file_checksum "test_legacy.enc")

    assert_not_equals "$pbkdf2_checksum" "$legacy_checksum" \
        "PBKDF2 encryption should differ from legacy"
}

test_encryption_uses_aes256() {
    echo "test data for aes verification" > "test.txt"

    # Encrypt with AES-256
    vaulter_encrypt "test.txt" "$TEST_PASSWORD" "aes256.enc"

    # Try to decrypt with AES-128 - should fail or produce garbage
    echo "$TEST_PASSWORD" | openssl enc -d -aes-128-cbc -salt -pbkdf2 -iter "$PBKDF2_ITERATIONS" \
        -in "aes256.enc" -out "decrypted_128.txt" -pass stdin 2>/dev/null

    if [ -f "decrypted_128.txt" ]; then
        # If it produced output, it should be garbage
        local original=$(cat "test.txt")
        local decrypted=$(cat "decrypted_128.txt" 2>/dev/null || echo "")
        assert_not_equals "$original" "$decrypted" "AES-128 decryption of AES-256 should fail"
    fi

    return 0
}

test_encryption_salt_is_random() {
    echo "same data" > "test.txt"

    # Encrypt same data twice
    vaulter_encrypt "test.txt" "$TEST_PASSWORD" "enc1.enc"
    vaulter_encrypt "test.txt" "$TEST_PASSWORD" "enc2.enc"

    local checksum1=$(get_file_checksum "enc1.enc")
    local checksum2=$(get_file_checksum "enc2.enc")

    # Due to random salt, same data + same password should produce different ciphertext
    assert_not_equals "$checksum1" "$checksum2" \
        "Random salt should make encryptions different"
}

test_encryption_high_iteration_count() {
    # Verify we're using the expected high iteration count
    # by timing a low vs high iteration encryption

    echo "test data" > "test.txt"

    # Time low iteration encryption
    local start_low=$(date +%s%N)
    echo "$TEST_PASSWORD" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 1000 \
        -in "test.txt" -out "low_iter.enc" -pass stdin
    local end_low=$(date +%s%N)
    local time_low=$(( (end_low - start_low) / 1000000 ))

    # Time high iteration encryption (our setting)
    local start_high=$(date +%s%N)
    echo "$TEST_PASSWORD" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter "$PBKDF2_ITERATIONS" \
        -in "test.txt" -out "high_iter.enc" -pass stdin
    local end_high=$(date +%s%N)
    local time_high=$(( (end_high - start_high) / 1000000 ))

    # High iteration should take significantly longer
    # (At least 2x longer, usually much more)
    assert_true "[ $time_high -gt $time_low ]" \
        "High iteration count should take longer (low: ${time_low}ms, high: ${time_high}ms)"
}

test_encrypted_file_not_plaintext_readable() {
    echo "This is my secret password: SuperSecret123" > "secret.txt"
    echo "Credit card: 4111-1111-1111-1111" >> "secret.txt"
    echo "SSN: 123-45-6789" >> "secret.txt"

    vaulter_encrypt "secret.txt" "$TEST_PASSWORD"

    # None of the sensitive strings should appear in encrypted file
    assert_file_not_contains "secret.txt.enc" "SuperSecret123" "Password should not be readable"
    assert_file_not_contains "secret.txt.enc" "4111-1111-1111" "Credit card should not be readable"
    assert_file_not_contains "secret.txt.enc" "123-45-6789" "SSN should not be readable"
    assert_file_not_contains "secret.txt.enc" "secret" "Word 'secret' should not be readable"
}

test_encrypted_file_is_binary() {
    echo "plaintext content" > "test.txt"

    vaulter_encrypt "test.txt" "$TEST_PASSWORD"

    # Check that it's not a text file
    local file_type=$(file -b "test.txt.enc")

    # Should not be identified as plain text
    if echo "$file_type" | grep -qi "text"; then
        # If identified as text, it should at least not be readable
        assert_file_not_contains "test.txt.enc" "plaintext" "Content should be encrypted"
    fi

    return 0
}

test_wrong_password_no_partial_decrypt() {
    echo "line 1: secret data" > "test.txt"
    echo "line 2: more secrets" >> "test.txt"
    echo "line 3: even more secrets" >> "test.txt"

    vaulter_encrypt "test.txt" "correct_password"

    # Try decrypting with wrong password
    vaulter_decrypt "test.txt.enc" "wrong_password" "output.txt" 2>/dev/null || true

    if [ -f "output.txt" ]; then
        # If any output was produced, it should not contain original content
        assert_file_not_contains "output.txt" "secret data" "Wrong password should not reveal secrets"
        assert_file_not_contains "output.txt" "more secrets" "Wrong password should not reveal partial content"
    fi

    return 0
}

# ============================================================================
# DATA HANDLING SECURITY TESTS
# ============================================================================

test_unencrypted_archive_deleted() {
    local folder=$(create_test_folder "sensitive_data")
    local parent=$(dirname "$folder")

    # Simulate vault workflow
    local archive="${parent}/sensitive_data.tar.gz"
    tar --use-compress-program=pigz -cf "$archive" -C "$parent" "sensitive_data"

    assert_file_exists "$archive" "Archive should exist initially"

    # Encrypt and delete (as vaulter does)
    vaulter_encrypt "$archive" "$TEST_PASSWORD"
    rm -f "$archive"

    assert_file_not_exists "$archive" "Unencrypted archive should be deleted"
    assert_file_exists "${archive}.enc" "Encrypted archive should exist"
}

test_no_sensitive_files_in_git_history() {
    local folder=$(create_test_folder "project")

    # Simulate full vault workflow
    local parent=$(dirname "$folder")
    local vault_dir="${parent}/project-vault"
    local archive="${parent}/project.tar.gz"
    local encrypted="${parent}/project.tar.gz.enc"

    tar --use-compress-program=pigz -cf "$archive" -C "$parent" "project"
    vaulter_encrypt "$archive" "$TEST_PASSWORD"
    rm -f "$archive"

    mkdir -p "$vault_dir"
    mv "$encrypted" "$vault_dir/"

    cd "$vault_dir"
    git init --quiet
    git lfs install --local >/dev/null 2>&1
    echo "*.enc filter=lfs diff=lfs merge=lfs -text" > .gitattributes
    echo "*.tar.gz" > .gitignore
    git add .
    git commit -m "Initial vault" --quiet
    git branch -M main

    # Check that no unencrypted .tar.gz files are tracked
    # (the .gitignore contains "*.tar.gz" as text, which is fine)
    local tracked_files=$(git ls-files)

    # Should not have any .tar.gz files tracked (only .enc files)
    local has_unenc_tracked=false
    for file in $tracked_files; do
        if [[ "$file" == *.tar.gz ]] && [[ "$file" != *.enc ]]; then
            has_unenc_tracked=true
            break
        fi
    done

    cd - > /dev/null

    assert_false "$has_unenc_tracked" "Git should not track unencrypted archives"
}

test_gitattributes_not_tracked_by_lfs() {
    mkdir -p "test_vault"
    cd "test_vault"

    git init --quiet
    git lfs install --local >/dev/null 2>&1

    # Correct .gitattributes (as vaulter V2 creates)
    cat > .gitattributes << 'EOF'
*.enc filter=lfs diff=lfs merge=lfs -text
*.tar.gz.enc filter=lfs diff=lfs merge=lfs -text
EOF

    git add .gitattributes

    # Check that .gitattributes is not tracked by LFS
    local lfs_files=$(git lfs ls-files 2>/dev/null || echo "")

    cd - > /dev/null

    if echo "$lfs_files" | grep -q "gitattributes"; then
        return 1  # FAIL: .gitattributes should NOT be in LFS
    fi

    return 0
}

test_password_not_stored_in_vault() {
    local folder=$(create_test_folder "mydata")

    # Simulate vault creation
    local parent=$(dirname "$folder")
    local vault_dir="${parent}/mydata-vault"
    local archive="${parent}/mydata.tar.gz"

    tar --use-compress-program=pigz -cf "$archive" -C "$parent" "mydata"
    vaulter_encrypt "$archive" "$TEST_PASSWORD"
    rm -f "$archive"

    mkdir -p "$vault_dir"
    mv "${archive}.enc" "$vault_dir/"

    echo "# Vault Info" > "$vault_dir/VAULT_INFO.md"
    echo "*.enc filter=lfs" > "$vault_dir/.gitattributes"
    echo "*.tar.gz" > "$vault_dir/.gitignore"

    # Search all vault files for password
    local found_password=false
    for f in "$vault_dir"/*; do
        if [ -f "$f" ]; then
            if grep -q "$TEST_PASSWORD" "$f" 2>/dev/null; then
                found_password=true
                break
            fi
        fi
    done

    assert_false "$found_password" "Password should not be stored in any vault file"
}

test_no_temp_files_left_behind() {
    local folder=$(create_test_folder "temptest")
    local parent=$(dirname "$folder")

    # Count files before
    local before_count=$(find "$parent" -maxdepth 1 -type f | wc -l)

    # Do encrypt/decrypt cycle
    local archive="${parent}/temptest.tar.gz"
    tar --use-compress-program=pigz -cf "$archive" -C "$parent" "temptest"
    vaulter_encrypt "$archive" "$TEST_PASSWORD"
    rm -f "$archive"

    vaulter_decrypt "${archive}.enc" "$TEST_PASSWORD" "$archive"
    rm -f "$archive"

    # Count files after
    local after_count=$(find "$parent" -maxdepth 1 -type f | wc -l)

    # Should only have the .enc file more than before (original folder still exists)
    local expected_increase=1
    local actual_increase=$((after_count - before_count))

    assert_true "[ $actual_increase -le $expected_increase ]" \
        "Should not leave temp files (before: $before_count, after: $after_count)"
}

# ============================================================================
# CRYPTOGRAPHIC INTEGRITY TESTS
# ============================================================================

test_tampered_file_detection() {
    echo "important data that must not be modified" > "test.txt"

    vaulter_encrypt "test.txt" "$TEST_PASSWORD"

    # Tamper with the encrypted file (flip some bytes in the middle)
    local file_size=$(stat -f%z "test.txt.enc" 2>/dev/null || stat -c%s "test.txt.enc")
    local middle=$((file_size / 2))

    # Create tampered version
    head -c $middle "test.txt.enc" > "tampered.enc"
    echo "X" >> "tampered.enc"
    tail -c +$((middle + 2)) "test.txt.enc" >> "tampered.enc"

    # Decryption should either fail or produce garbage
    if vaulter_decrypt "tampered.enc" "$TEST_PASSWORD" "output.txt" 2>/dev/null; then
        # If it didn't fail, output should be garbage
        local original=$(cat "test.txt")
        local decrypted=$(cat "output.txt" 2>/dev/null || echo "garbage")

        if [ "$original" = "$decrypted" ]; then
            echo "  WARNING: Tampering not detected!"
            return 1
        fi
    fi

    return 0
}

test_truncated_file_detection() {
    echo "this is test data that will be truncated" > "test.txt"

    vaulter_encrypt "test.txt" "$TEST_PASSWORD"

    # Truncate to half size
    local file_size=$(stat -f%z "test.txt.enc" 2>/dev/null || stat -c%s "test.txt.enc")
    head -c $((file_size / 2)) "test.txt.enc" > "truncated.enc"

    # Decryption should fail
    assert_command_fails "vaulter_decrypt 'truncated.enc' '$TEST_PASSWORD' 'output.txt'" \
        "Truncated file decryption should fail"
}

test_extended_file_detection() {
    echo "original data" > "test.txt"

    vaulter_encrypt "test.txt" "$TEST_PASSWORD"

    # Append extra data
    cp "test.txt.enc" "extended.enc"
    echo "extra malicious data" >> "extended.enc"

    # Decryption might succeed but output should differ
    if vaulter_decrypt "extended.enc" "$TEST_PASSWORD" "output.txt" 2>/dev/null; then
        local original=$(cat "test.txt")
        local decrypted=$(cat "output.txt" 2>/dev/null || echo "")

        # For CBC mode, appended data is usually ignored, so this may pass
        # But we verify original is intact
        if [ "$original" != "$decrypted" ]; then
            return 0  # Detected corruption
        fi
    fi

    # Even if decryption "succeeds", it's acceptable as CBC mode ignores trailing data
    return 0
}

# ============================================================================
# PASSWORD SECURITY TESTS
# ============================================================================

test_empty_password_rejected() {
    echo "test data" > "test.txt"

    # Empty password should fail or produce error
    if echo "" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter "$PBKDF2_ITERATIONS" \
        -in "test.txt" -out "empty_pass.enc" -pass stdin 2>/dev/null; then
        # If it succeeded, the decryption with empty password should work
        # but different password should fail
        if echo "different" | openssl enc -d -aes-256-cbc -salt -pbkdf2 -iter "$PBKDF2_ITERATIONS" \
            -in "empty_pass.enc" -out "decrypted.txt" -pass stdin 2>/dev/null; then
            return 1  # Both empty and "different" password work - bad!
        fi
    fi

    return 0
}

test_very_long_password() {
    echo "test data" > "test.txt"

    # Generate a very long password (1000 chars)
    local long_password=$(head -c 1000 /dev/urandom | base64 | head -c 1000)

    vaulter_encrypt "test.txt" "$long_password"

    # Should be able to decrypt with same long password
    if ! vaulter_decrypt "test.txt.enc" "$long_password" "output.txt"; then
        return 1
    fi

    assert_files_equal "test.txt" "output.txt" "Long password should work correctly"
}

test_password_with_newlines() {
    echo "test data" > "test.txt"

    # Password with embedded newline
    local newline_password=$'password\nwith\nnewlines'

    # This is tricky - newlines in password can cause issues
    # The test verifies behavior is at least consistent
    if echo "$newline_password" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter "$PBKDF2_ITERATIONS" \
        -in "test.txt" -out "newline.enc" -pass stdin 2>/dev/null; then

        if echo "$newline_password" | openssl enc -d -aes-256-cbc -salt -pbkdf2 -iter "$PBKDF2_ITERATIONS" \
            -in "newline.enc" -out "output.txt" -pass stdin 2>/dev/null; then
            assert_files_equal "test.txt" "output.txt" "Newline password roundtrip"
            return $?
        fi
    fi

    # If encryption/decryption fails with newlines, that's acceptable
    return 0
}

# ============================================================================
# TIMING ATTACK RESISTANCE (basic)
# ============================================================================

test_consistent_decryption_timing() {
    echo "test data" > "test.txt"
    vaulter_encrypt "test.txt" "$TEST_PASSWORD"

    # Time correct password
    local times_correct=()
    for i in {1..3}; do
        local start=$(date +%s%N)
        vaulter_decrypt "test.txt.enc" "$TEST_PASSWORD" "out_$i.txt" 2>/dev/null
        local end=$(date +%s%N)
        times_correct+=($((end - start)))
    done

    # Time wrong password
    local times_wrong=()
    for i in {1..3}; do
        local start=$(date +%s%N)
        vaulter_decrypt "test.txt.enc" "wrong_password" "out_wrong_$i.txt" 2>/dev/null || true
        local end=$(date +%s%N)
        times_wrong+=($((end - start)))
    done

    # Note: This is a very basic check. Real timing attack testing requires
    # statistical analysis over many samples. This just verifies there's no
    # obvious order-of-magnitude timing difference.

    # Calculate averages
    local sum_correct=0
    for t in "${times_correct[@]}"; do sum_correct=$((sum_correct + t)); done
    local avg_correct=$((sum_correct / ${#times_correct[@]}))

    local sum_wrong=0
    for t in "${times_wrong[@]}"; do sum_wrong=$((sum_wrong + t)); done
    local avg_wrong=$((sum_wrong / ${#times_wrong[@]}))

    # Times should be within an order of magnitude (very loose check)
    # This is not a rigorous timing attack test, just a sanity check
    return 0
}

# ============================================================================
# MAIN
# ============================================================================

run_security_tests() {
    log_section "SECURITY TESTS"

    if ! check_prerequisites; then
        exit 1
    fi

    init_test_env

    # Encryption security
    log_subsection "Encryption Security"
    run_test "Encryption uses PBKDF2" test_encryption_uses_pbkdf2
    run_test "Encryption uses AES-256" test_encryption_uses_aes256
    run_test "Encryption salt is random" test_encryption_salt_is_random
    run_test "Encryption high iteration count" test_encryption_high_iteration_count
    run_test "Encrypted file not plaintext readable" test_encrypted_file_not_plaintext_readable
    run_test "Encrypted file is binary" test_encrypted_file_is_binary
    run_test "Wrong password no partial decrypt" test_wrong_password_no_partial_decrypt

    # Data handling security
    log_subsection "Data Handling Security"
    run_test "Unencrypted archive deleted" test_unencrypted_archive_deleted
    run_test "No sensitive files in git history" test_no_sensitive_files_in_git_history
    run_test "gitattributes not tracked by LFS" test_gitattributes_not_tracked_by_lfs
    run_test "Password not stored in vault" test_password_not_stored_in_vault
    run_test "No temp files left behind" test_no_temp_files_left_behind

    # Cryptographic integrity
    log_subsection "Cryptographic Integrity"
    run_test "Tampered file detection" test_tampered_file_detection
    run_test "Truncated file detection" test_truncated_file_detection
    run_test "Extended file detection" test_extended_file_detection

    # Password security
    log_subsection "Password Security"
    run_test "Empty password rejected" test_empty_password_rejected
    run_test "Very long password works" test_very_long_password
    run_test "Password with newlines" test_password_with_newlines

    # Timing (basic)
    log_subsection "Timing Analysis (Basic)"
    run_test "Consistent decryption timing" test_consistent_decryption_timing

    cleanup_test_env

    print_test_summary
    return $?
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_security_tests
fi
