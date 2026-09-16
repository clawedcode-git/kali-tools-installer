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
    FORCE_DISTRO="arch" detect_distro
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

test_column_parsing_void_pkg() {
    test_log "Testing 12-column parsing does not corrupt void_pkg with deps..."
    local old_family="${DISTRO_FAMILY}"
    DISTRO_FAMILY="void"
    local pkg
    pkg=$(get_distro_pkg_name "nmap")
    DISTRO_FAMILY="${old_family}"
    if [[ "${pkg}" == *"|"* ]]; then
        test_log "FAIL: void_pkg contains pipe/deps: '${pkg}'"
        return 1
    fi
    if [[ "${pkg}" != "nmap" ]]; then
        test_log "FAIL: expected void_pkg 'nmap', got '${pkg}'"
        return 1
    fi
    test_log "PASS: 12-column parsing correctly isolated void_pkg ('${pkg}')"
}

test_prompt_yes_no_default() {
    test_log "Testing prompt_yes_no default behavior..."
    local res_y res_n
    if echo "" | (ASSUME_YES=false prompt_yes_no "Accept?" "y"); then
        res_y=0
    else
        res_y=1
    fi
    if echo "" | (ASSUME_YES=false prompt_yes_no "Accept?" "n"); then
        res_n=0
    else
        res_n=1
    fi
    [[ ${res_y} -eq 0 ]] || { test_log "FAIL: prompt_yes_no default 'y' did not return 0"; return 1; }
    [[ ${res_n} -eq 1 ]] || { test_log "FAIL: prompt_yes_no default 'n' did not return 1"; return 1; }
    test_log "PASS: prompt_yes_no respects defaults on empty input"
}

test_utils_standalone_source() {
    test_log "Testing lib/utils.sh standalone sourcing without predefined PROJECT_ROOT..."
    local out
    if ! out=$(bash -c 'source lib/utils.sh; echo "PROJECT_ROOT=${PROJECT_ROOT}"' 2>&1); then
        test_log "FAIL: sourcing lib/utils.sh failed: ${out}"
        return 1
    fi
    test_log "PASS: lib/utils.sh sources cleanly without PROJECT_ROOT: ${out}"
}

test_invalid_option_handling() {
    test_log "Testing invalid option handling does not crash with unbound variable..."
    local out
    out=$(bash install.sh --invalid-test-flag 2>&1 || true)
    if echo "${out}" | grep -q "unbound variable"; then
        test_log "FAIL: install.sh crashed with unbound variable on invalid flag: ${out}"
        return 1
    fi
    if ! echo "${out}" | grep -q "Unknown option"; then
        test_log "FAIL: install.sh did not report 'Unknown option': ${out}"
        return 1
    fi
    test_log "PASS: invalid option safely caught and reported"
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

test_in_memory_package_cache() {
    test_log "Testing in-memory package cache population..."
    [[ ${#TOOL_PKG_MAPPINGS[@]} -gt 200 ]] || { test_log "FAIL: Too few mappings in TOOL_PKG_MAPPINGS: ${#TOOL_PKG_MAPPINGS[@]}"; return 1; }
    [[ -n "${TOOL_PKG_MAPPINGS["debian:nmap"]:-}" ]] || { test_log "FAIL: debian:nmap not found in cache"; return 1; }
    [[ -n "${TOOL_PKG_MAPPINGS["arch:nmap"]:-}" ]] || { test_log "FAIL: arch:nmap not found in cache"; return 1; }
    [[ -n "${TOOL_PKG_MAPPINGS["fedora:nmap"]:-}" ]] || { test_log "FAIL: fedora:nmap not found in cache"; return 1; }
    test_log "PASS: TOOL_PKG_MAPPINGS populated with ${#TOOL_PKG_MAPPINGS[@]} mappings"
}

test_multiple_distro_mappings() {
    test_log "Testing get_distro_pkg_name resolution across multiple distros..."
    local old_family="${DISTRO_FAMILY}"
    
    DISTRO_FAMILY="debian"
    local deb_pkg
    deb_pkg=$(get_distro_pkg_name "wireshark")
    
    DISTRO_FAMILY="arch"
    local arch_pkg
    arch_pkg=$(get_distro_pkg_name "wireshark")
    
    DISTRO_FAMILY="${old_family}"
    
    [[ "${deb_pkg}" == "wireshark" ]] || { test_log "FAIL: wireshark on debian expected 'wireshark', got '${deb_pkg}'"; return 1; }
    [[ "${arch_pkg}" == "wireshark-qt" ]] || { test_log "FAIL: wireshark on arch expected 'wireshark-qt', got '${arch_pkg}'"; return 1; }
    test_log "PASS: multi-distro lookup verified (debian=${deb_pkg}, arch=${arch_pkg})"
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

test_dry_run_unprivileged() {
    test_log "Testing dry-run without root privilege..."
    local out
    if ! out=$(bash "${PROJECT_ROOT}/install.sh" --distro arch --dry-run --tools nmap 2>&1); then
        test_log "FAIL: dry run failed: ${out}"
        return 1
    fi
    echo "${out}" | grep -q "Dry run complete" || { test_log "FAIL: Dry run completion message missing: ${out}"; return 1; }
    test_log "PASS: dry-run executed successfully without root"
}

test_precheck_execution() {
    test_log "Testing precheck execution without root privilege..."
    local out
    if ! out=$(bash "${PROJECT_ROOT}/install.sh" --distro arch --categories web --precheck 2>&1); then
        test_log "FAIL: precheck failed: ${out}"
        return 1
    fi
    echo "${out}" | grep -q "Precheck Summary" || { test_log "FAIL: Precheck Summary missing: ${out}"; return 1; }
    test_log "PASS: precheck executed successfully without root"
}

run_tests() {
    test_log "=== Starting Kali Tools Installer Tests ==="
    test_log "Test log: ${TEST_LOG}"
    
    local failed=0
    
    test_detect_distro || ((failed++))
    test_utils_standalone_source || ((failed++))
    test_invalid_option_handling || ((failed++))
    test_load_tool_list || ((failed++))
    test_column_parsing_void_pkg || ((failed++))
    test_prompt_yes_no_default || ((failed++))
    test_dry_run_unprivileged || ((failed++))
    test_precheck_execution || ((failed++))
    test_get_categories || ((failed++))
    test_get_tools_in_category || ((failed++))
    test_get_distro_pkg_name || ((failed++))
    test_in_memory_package_cache || ((failed++))
    test_multiple_distro_mappings || ((failed++))
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