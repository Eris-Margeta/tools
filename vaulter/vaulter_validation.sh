#!/bin/bash

# ============================================================================
# VAULTER VALIDATION SUITE
# ============================================================================
# Comprehensive validation and testing for Vaulter V2
#
# Usage:
#   ./vaulter_validation.sh           # Run all tests
#   ./vaulter_validation.sh unit      # Run only unit tests
#   ./vaulter_validation.sh integration  # Run only integration tests
#   ./vaulter_validation.sh security  # Run only security tests
#   ./vaulter_validation.sh quick     # Run quick smoke tests
#   ./vaulter_validation.sh --help    # Show help
#
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTING_DIR="$SCRIPT_DIR/testing_tools"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

VERSION="2.0.0"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

print_banner() {
    echo -e "${BOLD}${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                       ║"
    echo "║              VAULTER V2 - VALIDATION SUITE                            ║"
    echo "║                                                                       ║"
    echo "║              Comprehensive Testing & Validation                       ║"
    echo "║                                                                       ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

print_help() {
    echo "Vaulter Validation Suite v$VERSION"
    echo
    echo "Usage: $0 [command] [options]"
    echo
    echo "Commands:"
    echo "  all           Run all tests (default)"
    echo "  unit          Run unit tests only"
    echo "  integration   Run integration tests only"
    echo "  security      Run security tests only"
    echo "  quick         Run quick smoke tests"
    echo "  list          List all available tests"
    echo "  prereq        Check prerequisites only"
    echo
    echo "Options:"
    echo "  --verbose     Show detailed output"
    echo "  --no-cleanup  Don't clean up test artifacts"
    echo "  --help        Show this help message"
    echo
    echo "Examples:"
    echo "  $0                  # Run all tests"
    echo "  $0 unit             # Run unit tests only"
    echo "  $0 security         # Run security tests only"
    echo "  $0 quick            # Quick validation"
    echo
}

check_prerequisites() {
    echo -e "${BOLD}Checking prerequisites...${NC}"
    echo

    local all_ok=true
    local tools=("pigz" "openssl" "git" "git-lfs" "shasum" "tar")

    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            local version=$($tool --version 2>&1 | head -1 || echo "installed")
            echo -e "  ${GREEN}✓${NC} $tool"
        else
            echo -e "  ${RED}✗${NC} $tool (missing)"
            all_ok=false
        fi
    done

    echo

    if [ "$all_ok" = false ]; then
        echo -e "${RED}Missing prerequisites. Install with:${NC}"
        echo "  macOS:  brew install pigz openssl git git-lfs"
        echo "  Linux:  sudo apt install pigz openssl git git-lfs"
        return 1
    fi

    echo -e "${GREEN}All prerequisites satisfied.${NC}"
    return 0
}

check_test_files() {
    local missing=()

    [ ! -f "$TESTING_DIR/test_utils.sh" ] && missing+=("test_utils.sh")
    [ ! -f "$TESTING_DIR/unit_tests.sh" ] && missing+=("unit_tests.sh")
    [ ! -f "$TESTING_DIR/integration_tests.sh" ] && missing+=("integration_tests.sh")
    [ ! -f "$TESTING_DIR/security_tests.sh" ] && missing+=("security_tests.sh")

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}Missing test files: ${missing[*]}${NC}"
        echo "Test files should be in: $TESTING_DIR"
        return 1
    fi

    return 0
}

list_tests() {
    echo -e "${BOLD}Available Test Suites:${NC}"
    echo
    echo -e "${CYAN}Unit Tests${NC} (testing_tools/unit_tests.sh)"
    echo "  - Compression tests (7 tests)"
    echo "  - Encryption tests (8 tests)"
    echo "  - Decryption tests (5 tests)"
    echo "  - Decompression tests (2 tests)"
    echo "  - Git LFS configuration tests (4 tests)"
    echo "  - Roundtrip tests (3 tests)"
    echo
    echo -e "${CYAN}Integration Tests${NC} (testing_tools/integration_tests.sh)"
    echo "  - Vault workflow tests (9 tests)"
    echo "  - De-vault workflow tests (4 tests)"
    echo "  - Full cycle tests (7 tests)"
    echo "  - Edge case tests (3 tests)"
    echo
    echo -e "${CYAN}Security Tests${NC} (testing_tools/security_tests.sh)"
    echo "  - Encryption security (7 tests)"
    echo "  - Data handling security (5 tests)"
    echo "  - Cryptographic integrity (3 tests)"
    echo "  - Password security (3 tests)"
    echo "  - Timing analysis (1 test)"
    echo
    echo -e "${BOLD}Total: ~65+ tests${NC}"
}

# ============================================================================
# QUICK SMOKE TESTS
# ============================================================================

run_quick_tests() {
    echo -e "${BOLD}${BLUE}Running Quick Smoke Tests...${NC}"
    echo

    local temp_dir=$(mktemp -d)
    local passed=0
    local failed=0

    cd "$temp_dir"

    # Test 1: Basic compression
    echo -n "  [1/5] Basic compression... "
    mkdir -p test_folder && echo "content" > test_folder/file.txt
    if tar --use-compress-program=pigz -cf test.tar.gz test_folder 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
        ((passed++))
    else
        echo -e "${RED}FAIL${NC}"
        ((failed++))
    fi

    # Test 2: Basic encryption
    echo -n "  [2/5] Basic encryption... "
    if echo "password" | openssl enc -aes-256-cbc -salt -pbkdf2 -iter 600000 \
        -in test.tar.gz -out test.tar.gz.enc -pass stdin 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
        ((passed++))
    else
        echo -e "${RED}FAIL${NC}"
        ((failed++))
    fi

    # Test 3: Basic decryption
    echo -n "  [3/5] Basic decryption... "
    if echo "password" | openssl enc -d -aes-256-cbc -salt -pbkdf2 -iter 600000 \
        -in test.tar.gz.enc -out decrypted.tar.gz -pass stdin 2>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
        ((passed++))
    else
        echo -e "${RED}FAIL${NC}"
        ((failed++))
    fi

    # Test 4: Git LFS available
    echo -n "  [4/5] Git LFS available... "
    if git lfs version >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((passed++))
    else
        echo -e "${RED}FAIL${NC}"
        ((failed++))
    fi

    # Test 5: Data integrity
    echo -n "  [5/5] Data integrity... "
    rm -rf test_folder
    if tar -xzf decrypted.tar.gz && [ -f test_folder/file.txt ]; then
        local content=$(cat test_folder/file.txt)
        if [ "$content" = "content" ]; then
            echo -e "${GREEN}PASS${NC}"
            ((passed++))
        else
            echo -e "${RED}FAIL${NC}"
            ((failed++))
        fi
    else
        echo -e "${RED}FAIL${NC}"
        ((failed++))
    fi

    cd - > /dev/null
    rm -rf "$temp_dir"

    echo
    echo -e "${BOLD}Quick Test Results: $passed/5 passed${NC}"

    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}All quick tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some quick tests failed!${NC}"
        return 1
    fi
}

# ============================================================================
# TEST RUNNERS
# ============================================================================

run_unit_tests() {
    echo
    source "$TESTING_DIR/unit_tests.sh"
    run_unit_tests
    return $?
}

run_integration_tests() {
    echo
    source "$TESTING_DIR/integration_tests.sh"
    run_integration_tests
    return $?
}

run_security_tests() {
    echo
    source "$TESTING_DIR/security_tests.sh"
    run_security_tests
    return $?
}

run_all_tests() {
    local start_time=$(date +%s)
    local start_datetime=$(date "+%Y-%m-%d %H:%M:%S")

    local unit_result=0
    local integration_result=0
    local security_result=0
    local unit_passed=0 unit_failed=0
    local integration_passed=0 integration_failed=0
    local security_passed=0 security_failed=0

    # Run unit tests and capture results
    (
        source "$TESTING_DIR/unit_tests.sh"
        run_unit_tests
    )
    unit_result=$?

    # Run integration tests
    (
        source "$TESTING_DIR/integration_tests.sh"
        run_integration_tests
    )
    integration_result=$?

    # Run security tests
    (
        source "$TESTING_DIR/security_tests.sh"
        run_security_tests
    )
    security_result=$?

    local end_time=$(date +%s)
    local end_datetime=$(date "+%Y-%m-%d %H:%M:%S")
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    # Get system info
    local os_name=$(uname -s)
    local os_version=$(uname -r)
    local hostname=$(hostname -s 2>/dev/null || hostname)
    local shell_version=$BASH_VERSION

    # Print final report
    echo
    echo
    echo -e "${BOLD}${CYAN}╔═════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║                                                                             ║${NC}"
    echo -e "${BOLD}${CYAN}║                    VAULTER V2 - TEST REPORT                                 ║${NC}"
    echo -e "${BOLD}${CYAN}║                                                                             ║${NC}"
    echo -e "${BOLD}${CYAN}╚═════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${BOLD}┌─────────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}│ REPORT METADATA                                                                 │${NC}"
    echo -e "${BOLD}├─────────────────────────────────────────────────────────────────────────────────┤${NC}"
    printf "│  %-20s %-56s │\n" "Date:" "$start_datetime"
    printf "│  %-20s %-56s │\n" "Vaulter Version:" "$VERSION"
    printf "│  %-20s %-56s │\n" "System:" "$os_name $os_version"
    printf "│  %-20s %-56s │\n" "Hostname:" "$hostname"
    printf "│  %-20s %-56s │\n" "Shell:" "bash $shell_version"
    echo -e "${BOLD}└─────────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo
    echo -e "${BOLD}┌─────────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}│ TEST RESULTS                                                                    │${NC}"
    echo -e "${BOLD}├─────────────────────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${BOLD}│                                                                                 │${NC}"

    # Unit Tests
    if [ $unit_result -eq 0 ]; then
        echo -e "│  ${GREEN}✓${NC} ${BOLD}Unit Tests${NC}                                                                  │"
        echo -e "│    └── Status: ${GREEN}PASSED${NC}  (29 tests)                                              │"
    else
        echo -e "│  ${RED}✗${NC} ${BOLD}Unit Tests${NC}                                                                  │"
        echo -e "│    └── Status: ${RED}FAILED${NC}                                                           │"
    fi
    echo "│                                                                                 │"

    # Integration Tests
    if [ $integration_result -eq 0 ]; then
        echo -e "│  ${GREEN}✓${NC} ${BOLD}Integration Tests${NC}                                                           │"
        echo -e "│    └── Status: ${GREEN}PASSED${NC}  (23 tests)                                              │"
    else
        echo -e "│  ${RED}✗${NC} ${BOLD}Integration Tests${NC}                                                           │"
        echo -e "│    └── Status: ${RED}FAILED${NC}                                                           │"
    fi
    echo "│                                                                                 │"

    # Security Tests
    if [ $security_result -eq 0 ]; then
        echo -e "│  ${GREEN}✓${NC} ${BOLD}Security Tests${NC}                                                              │"
        echo -e "│    └── Status: ${GREEN}PASSED${NC}  (19 tests)                                              │"
    else
        echo -e "│  ${RED}✗${NC} ${BOLD}Security Tests${NC}                                                              │"
        echo -e "│    └── Status: ${RED}FAILED${NC}                                                           │"
    fi
    echo "│                                                                                 │"
    echo -e "${BOLD}├─────────────────────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${BOLD}│ SUMMARY                                                                         │${NC}"
    echo -e "${BOLD}├─────────────────────────────────────────────────────────────────────────────────┤${NC}"

    local total_tests=71
    local total_passed=0
    local total_failed=0

    [ $unit_result -eq 0 ] && total_passed=$((total_passed + 29)) || total_failed=$((total_failed + 29))
    [ $integration_result -eq 0 ] && total_passed=$((total_passed + 23)) || total_failed=$((total_failed + 23))
    [ $security_result -eq 0 ] && total_passed=$((total_passed + 19)) || total_failed=$((total_failed + 19))

    printf "│  %-20s %-56s │\n" "Total Tests:" "$total_tests"
    echo -e "│  Passed:              ${GREEN}${total_passed}${NC}                                                        │"
    echo -e "│  Failed:              ${RED}${total_failed}${NC}                                                         │"
    printf "│  %-20s %-56s │\n" "Duration:" "${minutes}m ${seconds}s"
    printf "│  %-20s %-56s │\n" "Completed:" "$end_datetime"
    echo -e "${BOLD}└─────────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo

    if [ $unit_result -eq 0 ] && [ $integration_result -eq 0 ] && [ $security_result -eq 0 ]; then
        echo -e "${GREEN}${BOLD}╔═════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}${BOLD}║                                                                             ║${NC}"
        echo -e "${GREEN}${BOLD}║                         ✓ ALL 71 TESTS PASSED                               ║${NC}"
        echo -e "${GREEN}${BOLD}║                                                                             ║${NC}"
        echo -e "${GREEN}${BOLD}║                    Vaulter V2 is ready for use.                             ║${NC}"
        echo -e "${GREEN}${BOLD}║                                                                             ║${NC}"
        echo -e "${GREEN}${BOLD}╚═════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo
        return 0
    else
        echo -e "${RED}${BOLD}╔═════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}${BOLD}║                                                                             ║${NC}"
        echo -e "${RED}${BOLD}║                         ✗ SOME TESTS FAILED                                 ║${NC}"
        echo -e "${RED}${BOLD}║                                                                             ║${NC}"
        echo -e "${RED}${BOLD}║              Please review the output above for details.                    ║${NC}"
        echo -e "${RED}${BOLD}║                                                                             ║${NC}"
        echo -e "${RED}${BOLD}╚═════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo
        return 1
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    print_banner

    local command="${1:-all}"

    case "$command" in
        --help|-h|help)
            print_help
            exit 0
            ;;
        prereq|prerequisites)
            check_prerequisites
            exit $?
            ;;
        list)
            list_tests
            exit 0
            ;;
        quick|smoke)
            check_prerequisites || exit 1
            run_quick_tests
            exit $?
            ;;
        unit)
            check_prerequisites || exit 1
            check_test_files || exit 1
            run_unit_tests
            exit $?
            ;;
        integration)
            check_prerequisites || exit 1
            check_test_files || exit 1
            run_integration_tests
            exit $?
            ;;
        security)
            check_prerequisites || exit 1
            check_test_files || exit 1
            run_security_tests
            exit $?
            ;;
        all|full)
            check_prerequisites || exit 1
            check_test_files || exit 1
            run_all_tests
            exit $?
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
}

main "$@"
