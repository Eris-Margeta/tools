#!/bin/bash

# ============================================================================
# TEST UTILITIES
# Common functions and utilities for Vaulter test suite
# ============================================================================

# Colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export BOLD='\033[1m'
export NC='\033[0m'

# Test counters
export TESTS_RUN=0
export TESTS_PASSED=0
export TESTS_FAILED=0
export TESTS_SKIPPED=0

# Test environment
export TEST_DIR=""
export TEST_TEMP_DIR=""
export VAULTER_SCRIPT=""

# Configuration (must match vaulter.sh)
export PBKDF2_ITERATIONS=600000
export CIPHER="aes-256-cbc"
export TEST_PASSWORD="TestPassword123!@#"

# ============================================================================
# OUTPUT FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

log_section() {
    echo
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo
}

log_subsection() {
    echo
    echo -e "${BOLD}── $1 ──${NC}"
    echo
}

# ============================================================================
# TEST FRAMEWORK
# ============================================================================

# Initialize test environment
init_test_env() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    export TEST_DIR="$script_dir"
    export VAULTER_SCRIPT="$(dirname "$script_dir")/vaulter.sh"

    # Create temp directory for tests
    export TEST_TEMP_DIR=$(mktemp -d)

    if [ ! -f "$VAULTER_SCRIPT" ]; then
        echo "ERROR: vaulter.sh not found at $VAULTER_SCRIPT"
        exit 1
    fi

    log_info "Test environment initialized"
    log_info "Temp directory: $TEST_TEMP_DIR"
    log_info "Vaulter script: $VAULTER_SCRIPT"
}

# Cleanup test environment
cleanup_test_env() {
    if [ -n "$TEST_TEMP_DIR" ] && [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "$TEST_TEMP_DIR"
        log_info "Cleaned up temp directory"
    fi
}

# Run a single test
# Usage: run_test "test_name" test_function
run_test() {
    local test_name="$1"
    local test_func="$2"

    ((TESTS_RUN++))

    # Create isolated directory for this test
    local test_sandbox="$TEST_TEMP_DIR/test_$TESTS_RUN"
    mkdir -p "$test_sandbox"

    # Run the test
    local start_time=$(date +%s%N)
    local result

    (
        cd "$test_sandbox"
        $test_func
    )
    result=$?

    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))

    if [ $result -eq 0 ]; then
        ((TESTS_PASSED++))
        log_success "$test_name (${duration}ms)"
        return 0
    elif [ $result -eq 2 ]; then
        ((TESTS_SKIPPED++))
        log_skip "$test_name"
        return 2
    else
        ((TESTS_FAILED++))
        log_fail "$test_name (${duration}ms)"
        return 1
    fi
}

# Skip a test
skip_test() {
    exit 2
}

# Assert functions
assert_true() {
    local condition="$1"
    local message="${2:-Assertion failed}"

    if eval "$condition"; then
        return 0
    else
        echo "  ASSERT FAILED: $message"
        echo "  Condition: $condition"
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-Assertion failed}"

    if ! eval "$condition"; then
        return 0
    else
        echo "  ASSERT FAILED: $message"
        echo "  Expected false: $condition"
        return 1
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values not equal}"

    if [ "$expected" = "$actual" ]; then
        return 0
    else
        echo "  ASSERT FAILED: $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        return 1
    fi
}

assert_not_equals() {
    local unexpected="$1"
    local actual="$2"
    local message="${3:-Values should not be equal}"

    if [ "$unexpected" != "$actual" ]; then
        return 0
    else
        echo "  ASSERT FAILED: $message"
        echo "  Should not be: $unexpected"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"

    if [ -f "$file" ]; then
        return 0
    else
        echo "  ASSERT FAILED: $message"
        echo "  File not found: $file"
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist}"

    if [ ! -f "$file" ]; then
        return 0
    else
        echo "  ASSERT FAILED: $message"
        echo "  File exists: $file"
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    local message="${2:-Directory should exist}"

    if [ -d "$dir" ]; then
        return 0
    else
        echo "  ASSERT FAILED: $message"
        echo "  Directory not found: $dir"
        return 1
    fi
}

assert_dir_not_exists() {
    local dir="$1"
    local message="${2:-Directory should not exist}"

    if [ ! -d "$dir" ]; then
        return 0
    else
        echo "  ASSERT FAILED: $message"
        echo "  Directory exists: $dir"
        return 1
    fi
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    local message="${3:-File should contain pattern}"

    if grep -q "$pattern" "$file" 2>/dev/null; then
        return 0
    else
        echo "  ASSERT FAILED: $message"
        echo "  File: $file"
        echo "  Pattern not found: $pattern"
        return 1
    fi
}

assert_file_not_contains() {
    local file="$1"
    local pattern="$2"
    local message="${3:-File should not contain pattern}"

    if ! grep -q "$pattern" "$file" 2>/dev/null; then
        return 0
    else
        echo "  ASSERT FAILED: $message"
        echo "  File: $file"
        echo "  Pattern found: $pattern"
        return 1
    fi
}

assert_command_succeeds() {
    local cmd="$1"
    local message="${2:-Command should succeed}"

    if eval "$cmd" >/dev/null 2>&1; then
        return 0
    else
        echo "  ASSERT FAILED: $message"
        echo "  Command failed: $cmd"
        return 1
    fi
}

assert_command_fails() {
    local cmd="$1"
    local message="${2:-Command should fail}"

    if ! eval "$cmd" >/dev/null 2>&1; then
        return 0
    else
        echo "  ASSERT FAILED: $message"
        echo "  Command succeeded (should have failed): $cmd"
        return 1
    fi
}

assert_files_equal() {
    local file1="$1"
    local file2="$2"
    local message="${3:-Files should be equal}"

    if diff -q "$file1" "$file2" >/dev/null 2>&1; then
        return 0
    else
        echo "  ASSERT FAILED: $message"
        echo "  Files differ: $file1 vs $file2"
        return 1
    fi
}

assert_file_size_greater_than() {
    local file="$1"
    local min_size="$2"
    local message="${3:-File should be larger}"

    local actual_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)

    if [ "$actual_size" -gt "$min_size" ]; then
        return 0
    else
        echo "  ASSERT FAILED: $message"
        echo "  File: $file"
        echo "  Expected size > $min_size, got $actual_size"
        return 1
    fi
}

# ============================================================================
# TEST DATA GENERATORS
# ============================================================================

# Create a test folder with sample content
create_test_folder() {
    local folder_name="${1:-test_folder}"
    local num_files="${2:-5}"

    mkdir -p "$folder_name"

    # Create various types of files
    echo "This is a text file" > "$folder_name/readme.txt"
    echo '{"key": "value", "number": 123}' > "$folder_name/config.json"

    # Create some random binary data
    dd if=/dev/urandom of="$folder_name/binary_data.bin" bs=1024 count=10 2>/dev/null

    # Create nested directories
    mkdir -p "$folder_name/subdir/nested"
    echo "Nested file content" > "$folder_name/subdir/nested/deep_file.txt"

    # Create files with various content
    for i in $(seq 1 $num_files); do
        echo "File content $i - $(date +%s%N)" > "$folder_name/file_$i.txt"
    done

    # Create a file with special characters in content
    echo "Special chars: !@#\$%^&*()_+-=[]{}|;':\",./<>?" > "$folder_name/special_chars.txt"

    echo "$folder_name"
}

# Create a test folder with specific size
create_test_folder_with_size() {
    local folder_name="${1:-test_folder}"
    local size_kb="${2:-100}"

    mkdir -p "$folder_name"

    dd if=/dev/urandom of="$folder_name/data.bin" bs=1024 count=$size_kb 2>/dev/null

    echo "$folder_name"
}

# Create a test folder with spaces in name
create_test_folder_with_spaces() {
    local folder_name="${1:-test folder with spaces}"

    mkdir -p "$folder_name"
    echo "Content" > "$folder_name/file.txt"

    echo "$folder_name"
}

# Create a test folder with unicode characters
create_test_folder_unicode() {
    local folder_name="${1:-test_unicode}"

    mkdir -p "$folder_name"
    echo "Unicode content" > "$folder_name/file.txt"
    mkdir -p "$folder_name/subdir"
    echo "Nested" > "$folder_name/subdir/nested.txt"

    echo "$folder_name"
}

# Get checksum of a folder (for integrity verification)
get_folder_checksum() {
    local folder="$1"

    # Use tar to create a consistent representation, then hash it
    tar -cf - -C "$(dirname "$folder")" "$(basename "$folder")" 2>/dev/null | shasum -a 256 | cut -d' ' -f1
}

# Get checksum of a file
get_file_checksum() {
    local file="$1"
    shasum -a 256 "$file" 2>/dev/null | cut -d' ' -f1
}

# ============================================================================
# VAULTER OPERATIONS (for testing)
# ============================================================================

# Compress a folder using vaulter's method
vaulter_compress() {
    local folder="$1"
    local output="${2:-$(dirname "$folder")/$(basename "$folder").tar.gz}"

    tar --use-compress-program=pigz -cf "$output" -C "$(dirname "$folder")" "$(basename "$folder")"
    echo "$output"
}

# Encrypt a file using vaulter's method
vaulter_encrypt() {
    local file="$1"
    local password="$2"
    local output="${3:-${file}.enc}"

    echo "$password" | openssl enc -"$CIPHER" -salt -pbkdf2 -iter "$PBKDF2_ITERATIONS" \
        -in "$file" -out "$output" -pass stdin
    echo "$output"
}

# Decrypt a file using vaulter's method
vaulter_decrypt() {
    local file="$1"
    local password="$2"
    local output="${3:-${file%.enc}}"

    echo "$password" | openssl enc -d -"$CIPHER" -salt -pbkdf2 -iter "$PBKDF2_ITERATIONS" \
        -in "$file" -out "$output" -pass stdin 2>/dev/null
    return $?
}

# Decompress an archive
vaulter_decompress() {
    local archive="$1"
    local dest="${2:-.}"

    tar -xzf "$archive" -C "$dest"
}

# ============================================================================
# PRINT TEST SUMMARY
# ============================================================================

print_test_summary() {
    echo
    echo -e "${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}                        TEST SUMMARY                            ${NC}"
    echo -e "${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo
    echo -e "  Total tests:   ${BOLD}$TESTS_RUN${NC}"
    echo -e "  ${GREEN}Passed:${NC}        ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed:${NC}        ${RED}$TESTS_FAILED${NC}"
    echo -e "  ${YELLOW}Skipped:${NC}       ${YELLOW}$TESTS_SKIPPED${NC}"
    echo

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}${BOLD}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}${BOLD}Some tests failed!${NC}"
        return 1
    fi
}

# ============================================================================
# PREREQUISITE CHECKS
# ============================================================================

check_prerequisites() {
    local missing=()

    command -v pigz >/dev/null 2>&1 || missing+=("pigz")
    command -v openssl >/dev/null 2>&1 || missing+=("openssl")
    command -v git >/dev/null 2>&1 || missing+=("git")
    command -v git-lfs >/dev/null 2>&1 || missing+=("git-lfs")
    command -v shasum >/dev/null 2>&1 || missing+=("shasum")

    if [ ${#missing[@]} -gt 0 ]; then
        echo "ERROR: Missing required tools: ${missing[*]}"
        echo "Install with: brew install ${missing[*]} (macOS)"
        return 1
    fi

    return 0
}
