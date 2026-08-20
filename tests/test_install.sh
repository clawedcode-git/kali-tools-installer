#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PROJECT_ROOT
export PROJECT_ROOT

# Set default LOG_FILE for testing
LOG_FILE="/tmp/kali-tools-test-install.log"
export LOG_FILE

source "${PROJECT_ROOT}/lib/utils.sh"
source "${PROJECT_ROOT}/lib/distro.sh"
source "${PROJECT_ROOT}/lib/packages.sh"
source "${PROJECT_ROOT}/lib/installer.sh"

TEST_LOG="/tmp/kali-tools-test.log"

test_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "${TEST_LOG}"
}

test_detect_distro() {
    test_log "Testing distribution detection..."
    detect_distro
    [[ -n "${DISTRO}" ]] || { test_log "FAIL: DISTRO not set"; return 1; }
    [[ -n "${PACKAGE_MANAGER}" ]] || { test_log "FAIL: PACKAGE_MANAGER not set"; return 1; }
    test_log "PASS: Detected ${DISTRO} with ${PACKAGE_MANAGER}"
}

test_load_tool_list() {
    test_log "Testing tool list loading..."
    load_tool_list
    [[ ${#TOOL_CATEGORIES[@]} -gt 100 ]] || { test_log "FAIL: Too few tools loaded: ${#TOOL_CATEGORIES[@]}"; return 1; }
    [[ ${#CATEGORY_TOOLS[@]} -gt 10 ]] || { test_log "FAIL: Too few categories: ${#CATEGORY_TOOLS[@]}"; return 1; }
    test_log "PASS: Loaded ${#TOOL_CATEGORIES[@]} tools in ${#CATEGORY_TOOLS[@]} categories"
}

test_get_categories() {
    test_log "Testing category listing..."
    local cats
    cats=$(get_categories)
    [[ -n "${cats}" ]] || { test_log "FAIL: No categories returned"; return 1; }
    echo "${cats}" | grep -q "info" || { test_log "FAIL: 'info' category missing"; return 1; }
    echo "${cats}" | grep -q "web" || { test_log "FAIL: 'web' category missing"; return 1; }
    test_log "PASS: Categories: $(echo "${cats}" | tr '\n' ' ')"
}

test_get_tools_in_category() {
    test_log "Testing tools in category..."
    local tools
    tools=$(get_tools_in_category "info")
    [[ -n "${tools}" ]] || { test_log "FAIL: No tools in 'info' category"; return 1; }
    echo "${tools}" | grep -q "nmap" || { test_log "FAIL: nmap not in info category"; return 1; }
    test_log "PASS: Tools in 'info': $(echo "${tools}" | wc -w) tools"
}

test_get_distro_pkg_name() {
    test_log "Testing package name mapping..."
    local pkg
    pkg=$(get_distro_pkg_name "nmap")
    [[ -n "${pkg}" ]] || { test_log "FAIL: No package mapping for nmap on ${DISTRO_FAMILY}"; return 1; }
    test_log "PASS: nmap -> ${pkg} on ${DISTRO_FAMILY}"
}

test_validate_tool() {
    test_log "Testing tool validation..."
    validate_tool "nmap" || { test_log "FAIL: nmap validation failed"; return 1; }
    ! validate_tool "nonexistent-tool-xyz" || { test_log "FAIL: Invalid tool passed validation"; return 1; }
    test_log "PASS: Tool validation works"
}

test_validate_category() {
    test_log "Testing category validation..."
    validate_category "info" || { test_log "FAIL: info category validation failed"; return 1; }
    ! validate_category "nonexistent-category" || { test_log "FAIL: Invalid category passed validation"; return 1; }
    test_log "PASS: Category validation works"
}

test_list_all_tools() {
    test_log "Testing list all tools..."
    local tools
    tools=$(list_all_tools)
    [[ $(echo "${tools}" | wc -l) -gt 100 ]] || { test_log "FAIL: Too few tools listed"; return 1; }
    test_log "PASS: Listed $(echo "${tools}" | wc -l) tools"
}

run_tests() {
    test_log "=== Starting Kali Tools Installer Tests ==="
    test_log "Test log: ${TEST_LOG}"
    
    local failed=0
    
    test_detect_distro || ((failed++))
    test_load_tool_list || ((failed++))
    test_get_categories || ((failed++))
    test_get_tools_in_category || ((failed++))
    test_get_distro_pkg_name || ((failed++))
    test_validate_tool || ((failed++))
    test_validate_category || ((failed++))
    test_list_all_tools || ((failed++))
    
    test_log "=== Test Summary ==="
    if [[ ${failed} -eq 0 ]]; then
        test_log "ALL TESTS PASSED"
        return 0
    else
        test_log "${failed} TEST(S) FAILED"
        return 1
    fi
}

run_tests