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

test_arch_package_completeness() {
    test_log "Testing Arch Linux package mapping completeness..."
    local missing=0
    for tool in $(list_all_tools); do
        local pkg="${TOOL_PKG_MAPPINGS["arch:${tool}"]:-}"
        if [[ -z "${pkg}" ]]; then
            ((missing+=1))
        fi
    done
    [[ ${missing} -eq 0 ]] || { test_log "FAIL: ${missing} tools missing Arch mappings"; return 1; }
    test_log "PASS: 100% Arch package mapping coverage verified (${#TOOL_CATEGORIES[@]} tools)"
}

test_build_from_source_recipe() {
    test_log "Testing build_from_source detection and dry-run..."
    local info
    info=$(check_build_from_source "gobuster")
    [[ "${info}" == "BUILDABLE:go:https://github.com/OJ/gobuster" ]] || { test_log "FAIL: unexpected gobuster recipe: ${info}"; return 1; }
    
    local dry_build
    dry_build=$(DRY_RUN=true build_from_source "gobuster")
    echo "${dry_build}" | grep -q "[DRY RUN]" || { test_log "FAIL: dry run build missing dry run message: ${dry_build}"; return 1; }
    test_log "PASS: build_from_source recipe and dry-run confirmed"
}

test_precheck_with_dry_run() {
    test_log "Testing combined --precheck and --dry-run execution..."
    local out
    if ! out=$(bash "${PROJECT_ROOT}/install.sh" --distro arch --categories web --precheck --dry-run 2>&1); then
        test_log "FAIL: combined precheck and dry-run failed: ${out}"
        return 1
    fi
    echo "${out}" | grep -q "Precheck Summary" || { test_log "FAIL: Precheck Summary missing in combined run: ${out}"; return 1; }
    echo "${out}" | grep -q "Dry run complete" || { test_log "FAIL: Dry run complete missing in combined run: ${out}"; return 1; }
    test_log "PASS: combined --precheck and --dry-run executed successfully"
}

test_log_file_no_ansi() {
    test_log "Testing log file contains no raw ANSI escape sequences..."
    local test_log_file="/tmp/kali-tools-ansi-test.log"
    rm -f "${test_log_file}"
    LOG_FILE="${test_log_file}" info "Testing info message with color" >/dev/null
    LOG_FILE="${test_log_file}" warn "Testing warning message with color" >/dev/null
    LOG_FILE="${test_log_file}" error "Testing error message with color" >/dev/null
    
    if grep -q $'\033' "${test_log_file}" 2>/dev/null; then
        test_log "FAIL: raw ANSI escape sequences found in log file"
        rm -f "${test_log_file}"
        return 1
    fi
    rm -f "${test_log_file}"
    test_log "PASS: log file is clean of raw ANSI escape sequences"
}

test_cli_arg_validation() {
    test_log "Testing CLI argument missing value validation..."
    local out
    out=$(bash "${PROJECT_ROOT}/install.sh" --distro 2>&1 || true)
    echo "${out}" | grep -q "Option --distro requires an argument" || { test_log "FAIL: missing arg for --distro not handled: ${out}"; return 1; }

    out=$(bash "${PROJECT_ROOT}/install.sh" --categories 2>&1 || true)
    echo "${out}" | grep -q "Option --categories requires an argument" || { test_log "FAIL: missing arg for --categories not handled: ${out}"; return 1; }

    out=$(bash "${PROJECT_ROOT}/install.sh" --distro --yes 2>&1 || true)
    echo "${out}" | grep -q "Option --distro requires an argument" || { test_log "FAIL: flag passed as value not caught: ${out}"; return 1; }

    test_log "PASS: CLI argument missing value validation verified"
}

test_print_summary_set_e() {
    test_log "Testing print_summary under set -euo pipefail..."
    local out
    # 1. Success case should exit 0
    if ! out=$(bash -c 'set -euo pipefail; source lib/utils.sh; DRY_RUN=false; INSTALL_RESULTS=("SUCCESS:nmap" "SKIPPED:tool2"); print_summary 2>&1'); then
        test_log "FAIL: print_summary crashed on success case under set -e: ${out}"
        return 1
    fi
    echo "${out}" | grep -q "Total packages: 2" || { test_log "FAIL: unexpected print_summary output: ${out}"; return 1; }

    # 2. Failure case should exit 1 (reporting failure) without arithmetic error
    local rc=0
    out=$(bash -c 'set -euo pipefail; source lib/utils.sh; DRY_RUN=false; INSTALL_RESULTS=("FAILED:badpkg"); print_summary 2>&1') || rc=$?
    [[ ${rc} -eq 1 ]] || { test_log "FAIL: print_summary did not exit 1 on failed package (rc=${rc})"; return 1; }
    echo "${out}" | grep -q "Failed: 1" || { test_log "FAIL: failure count missing: ${out}"; return 1; }

    test_log "PASS: print_summary operates cleanly under set -euo pipefail"
}

test_case_insensitive_distro() {
    test_log "Testing case-insensitive --distro flag..."
    FORCE_DISTRO="ARCH" detect_distro >/dev/null 2>&1
    [[ "${DISTRO}" == "arch" && "${PACKAGE_MANAGER}" == "pacman" ]] || { test_log "FAIL: uppercase ARCH not detected as arch/pacman"; return 1; }
    test_log "PASS: case-insensitive --distro ARCH normalized to arch/pacman"
}

test_mocked_os_release_distros() {
    test_log "Testing distro detection via mocked os-release files..."
    local mock_dir="/tmp/mock-os-release"
    mkdir -p "${mock_dir}"
    
    # 1. CachyOS
    cat << 'EOF' > "${mock_dir}/cachyos"
NAME="CachyOS"
ID=cachyos
ID_LIKE="arch"
EOF
    (
        FORCE_DISTRO="" OS_RELEASE_FILE="${mock_dir}/cachyos" detect_distro >/dev/null 2>&1
        [[ "${DISTRO}" == "arch" && "${PACKAGE_MANAGER}" == "pacman" ]]
    ) || { test_log "FAIL: CachyOS mock failed detection"; rm -rf "${mock_dir}"; return 1; }

    # 2. Ubuntu
    cat << 'EOF' > "${mock_dir}/ubuntu"
NAME="Ubuntu"
ID=ubuntu
ID_LIKE=debian
EOF
    (
        FORCE_DISTRO="" OS_RELEASE_FILE="${mock_dir}/ubuntu" detect_distro >/dev/null 2>&1
        [[ "${DISTRO}" == "debian" && "${PACKAGE_MANAGER}" == "apt" ]]
    ) || { test_log "FAIL: Ubuntu mock failed detection"; rm -rf "${mock_dir}"; return 1; }

    # 3. Fedora
    cat << 'EOF' > "${mock_dir}/fedora"
NAME="Fedora Linux"
ID=fedora
EOF
    (
        FORCE_DISTRO="" OS_RELEASE_FILE="${mock_dir}/fedora" detect_distro >/dev/null 2>&1
        [[ "${DISTRO}" == "fedora" && "${PACKAGE_MANAGER}" == "dnf" ]]
    ) || { test_log "FAIL: Fedora mock failed detection"; rm -rf "${mock_dir}"; return 1; }

    # 4. Alpine
    cat << 'EOF' > "${mock_dir}/alpine"
NAME="Alpine Linux"
ID=alpine
EOF
    (
        FORCE_DISTRO="" OS_RELEASE_FILE="${mock_dir}/alpine" detect_distro >/dev/null 2>&1
        [[ "${DISTRO}" == "alpine" && "${PACKAGE_MANAGER}" == "apk" ]]
    ) || { test_log "FAIL: Alpine mock failed detection"; rm -rf "${mock_dir}"; return 1; }

    # 5. Void
    cat << 'EOF' > "${mock_dir}/void"
NAME="void"
ID=void
EOF
    (
        FORCE_DISTRO="" OS_RELEASE_FILE="${mock_dir}/void" detect_distro >/dev/null 2>&1
        [[ "${DISTRO}" == "void" && "${PACKAGE_MANAGER}" == "xbps" ]]
    ) || { test_log "FAIL: Void mock failed detection"; rm -rf "${mock_dir}"; return 1; }

    rm -rf "${mock_dir}"
    test_log "PASS: Multi-distro detection via mocked os-release verified"
}

test_blackarch_setup_dry_run() {
    test_log "Testing BlackArch setup dry-run..."
    local out
    out=$(DISTRO_FAMILY="arch" DRY_RUN="true" setup_blackarch 2>&1)
    echo "${out}" | grep -q "Setting up BlackArch repository" || { test_log "FAIL: BlackArch setup message missing: ${out}"; return 1; }
    echo "${out}" | grep -q "[DRY RUN]" || { test_log "FAIL: BlackArch dry-run missing dry-run tags: ${out}"; return 1; }
    test_log "PASS: BlackArch setup dry-run verified"
}

test_presets_definition() {
    test_log "Testing tool presets definition and validation..."
    local presets
    presets=$(get_presets)
    for p in top10 default headless web wireless passwords; do
        echo "${presets}" | grep -q "^${p}$" || { test_log "FAIL: preset '${p}' missing from get_presets"; return 1; }
        validate_preset "${p}" || { test_log "FAIL: validate_preset failed for '${p}'"; return 1; }
        local -a p_tools=()
        read -ra p_tools <<< "$(get_tools_in_preset "${p}")"
        [[ ${#p_tools[@]} -gt 0 ]] || { test_log "FAIL: preset '${p}' has 0 tools"; return 1; }
        for t in "${p_tools[@]}"; do
            validate_tool "${t}" || { test_log "FAIL: preset '${p}' contains invalid tool '${t}'"; return 1; }
        done
    done
    test_log "PASS: All tool presets defined with valid tools"
}

test_preset_cli_dry_run() {
    test_log "Testing --preset CLI flag with dry-run..."
    local out
    out=$(bash "${PROJECT_ROOT}/install.sh" --distro arch --preset top10 --dry-run --yes 2>&1)
    echo "${out}" | grep -q "Selected preset 'top10' (10 tools)" || { test_log "FAIL: preset selection message missing in dry-run: ${out}"; return 1; }
    echo "${out}" | grep -q "Tools to install (10):" || { test_log "FAIL: expected 10 tools to install: ${out}"; return 1; }
    echo "${out}" | grep -q "nmap -> nmap" || { test_log "FAIL: nmap missing in top10 dry-run: ${out}"; return 1; }
    echo "${out}" | grep -q "sqlmap -> sqlmap" || { test_log "FAIL: sqlmap missing in top10 dry-run: ${out}"; return 1; }
    test_log "PASS: --preset top10 executed cleanly in dry-run mode"
}

test_preset_precheck() {
    test_log "Testing --preset CLI flag with precheck..."
    local out
    out=$(bash "${PROJECT_ROOT}/install.sh" --distro arch --preset top10 --precheck 2>&1)
    echo "${out}" | grep -q "Checking preset 'top10' (10 tools)" || { test_log "FAIL: preset precheck header missing: ${out}"; return 1; }
    echo "${out}" | grep -q "Precheck Summary (Preset: top10)" || { test_log "FAIL: preset precheck summary missing: ${out}"; return 1; }
    echo "${out}" | grep -q "Total tools: 10" || { test_log "FAIL: expected 10 tools in precheck: ${out}"; return 1; }
    test_log "PASS: --preset top10 precheck verified"
}

test_preset_validation() {
    test_log "Testing invalid preset error handling..."
    local out rc=0
    out=$(bash "${PROJECT_ROOT}/install.sh" --distro arch --preset invalid_xyz --dry-run 2>&1) || rc=$?
    [[ ${rc} -ne 0 ]] || { test_log "FAIL: invalid preset should exit non-zero"; return 1; }
    echo "${out}" | grep -q "Unknown preset: invalid_xyz" || { test_log "FAIL: expected 'Unknown preset' error: ${out}"; return 1; }
    test_log "PASS: Invalid preset rejected cleanly"
}

test_tool_deps_cache() {
    test_log "Testing TOOL_DEPS cache and get_tool_deps retrieval..."
    load_tool_list
    local nmap_deps
    nmap_deps=$(get_tool_deps "nmap")
    [[ "${nmap_deps}" == "python3-pip,curl" ]] || { test_log "FAIL: expected nmap deps 'python3-pip,curl', got '${nmap_deps}'"; return 1; }
    
    local ws_deps
    ws_deps=$(get_tool_deps "wireshark")
    [[ "${ws_deps}" == "libpcap" ]] || { test_log "FAIL: expected wireshark deps 'libpcap', got '${ws_deps}'"; return 1; }
    
    test_log "PASS: TOOL_DEPS cache correctly populated and queryable"
}

test_get_all_deps_for_tools() {
    test_log "Testing get_all_deps_for_tools aggregation and deduplication..."
    load_tool_list
    local deps=()
    mapfile -t deps < <(get_all_deps_for_tools "nmap" "wireshark" "tshark" "tcpdump" "bettercap")
    local dep_str="${deps[*]}"
    
    echo "${dep_str}" | grep -q "python3-pip" || { test_log "FAIL: missing python3-pip in aggregated deps: ${dep_str}"; return 1; }
    echo "${dep_str}" | grep -q "curl" || { test_log "FAIL: missing curl in aggregated deps: ${dep_str}"; return 1; }
    echo "${dep_str}" | grep -q "libpcap" || { test_log "FAIL: missing libpcap in aggregated deps: ${dep_str}"; return 1; }
    echo "${dep_str}" | grep -q "go" || { test_log "FAIL: missing go in aggregated deps: ${dep_str}"; return 1; }
    
    # Check that libpcap appears only once (deduplicated across wireshark, tshark, tcpdump, bettercap)
    local libpcap_count=0
    for d in "${deps[@]}"; do
        [[ "${d}" == "libpcap" ]] && ((libpcap_count+=1))
    done
    [[ ${libpcap_count} -eq 1 ]] || { test_log "FAIL: libpcap not deduplicated (count: ${libpcap_count})"; return 1; }
    
    test_log "PASS: get_all_deps_for_tools aggregates and deduplicates correctly"
}

test_resolve_dep_pkg() {
    test_log "Testing resolve_dep_pkg across distributions..."
    [[ $(resolve_dep_pkg "python3-pip" "arch") == "python-pip" ]] || { test_log "FAIL: arch python3-pip mapping"; return 1; }
    [[ $(resolve_dep_pkg "python3-pip" "alpine") == "py3-pip" ]] || { test_log "FAIL: alpine python3-pip mapping"; return 1; }
    [[ $(resolve_dep_pkg "go" "debian") == "golang-go" ]] || { test_log "FAIL: debian go mapping"; return 1; }
    [[ $(resolve_dep_pkg "go" "fedora") == "golang" ]] || { test_log "FAIL: fedora go mapping"; return 1; }
    [[ $(resolve_dep_pkg "libpcap" "debian") == "libpcap-dev" ]] || { test_log "FAIL: debian libpcap mapping"; return 1; }
    [[ $(resolve_dep_pkg "base-devel" "debian") == "build-essential" ]] || { test_log "FAIL: debian base-devel mapping"; return 1; }
    [[ $(resolve_dep_pkg "curl" "gentoo") == "net-misc/curl" ]] || { test_log "FAIL: gentoo curl mapping"; return 1; }
    test_log "PASS: resolve_dep_pkg translates accurately across distributions"
}

test_build_prerequisites() {
    test_log "Testing get_build_prerequisites for source builds..."
    local go_pre
    go_pre=$(get_build_prerequisites "go")
    echo "${go_pre}" | grep -q "go" || { test_log "FAIL: go prerequisites missing go"; return 1; }
    echo "${go_pre}" | grep -q "git" || { test_log "FAIL: go prerequisites missing git"; return 1; }
    
    local cmake_pre
    cmake_pre=$(get_build_prerequisites "cmake")
    echo "${cmake_pre}" | grep -q "cmake" || { test_log "FAIL: cmake prerequisites missing cmake"; return 1; }
    echo "${cmake_pre}" | grep -q "make" || { test_log "FAIL: cmake prerequisites missing make"; return 1; }
    echo "${cmake_pre}" | grep -q "gcc" || { test_log "FAIL: cmake prerequisites missing gcc"; return 1; }
    
    test_log "PASS: get_build_prerequisites definitions verified"
}

test_dependency_resolution_cli() {
    test_log "Testing dependency resolution via CLI dry-run and --no-deps..."
    local out
    out=$(bash "${PROJECT_ROOT}/install.sh" --distro arch --preset top10 --dry-run 2>&1)
    echo "${out}" | grep -q "Resolving dependencies for 10 tools" || { test_log "FAIL: dry run missing dependency resolution: ${out}"; return 1; }
    echo "${out}" | grep -q "Would install dependencies:" || { test_log "FAIL: dry run missing planned dependency install: ${out}"; return 1; }
    
    local out_nodeps
    out_nodeps=$(bash "${PROJECT_ROOT}/install.sh" --distro arch --preset top10 --dry-run --no-deps 2>&1)
    echo "${out_nodeps}" | grep -q "Dependency auto-installation skipped (--no-deps)" || { test_log "FAIL: --no-deps did not skip dependency resolution: ${out_nodeps}"; return 1; }
    
    test_log "PASS: CLI dependency resolution and --no-deps verified"
}

test_uninstall_cli_dry_run() {
    test_log "Testing --uninstall CLI flag with dry-run..."
    local out
    out=$(bash "${PROJECT_ROOT}/install.sh" --distro arch --tools nmap,wireshark --uninstall --dry-run 2>&1)
    echo "${out}" | grep -q "Starting uninstallation of 2 tools" || { test_log "FAIL: uninstall missing start message: ${out}"; return 1; }
    echo "${out}" | grep -q "pacman -R --noconfirm nmap wireshark-qt" || { test_log "FAIL: uninstall missing pacman -R command: ${out}"; return 1; }
    echo "${out}" | grep -q "Successfully uninstalled: 2" || { test_log "FAIL: uninstall summary missing count: ${out}"; return 1; }
    echo "${out}" | grep -q "Dry run complete" || { test_log "FAIL: uninstall missing dry run complete message: ${out}"; return 1; }
    test_log "PASS: --uninstall CLI dry-run verified"
}

test_uninstall_preset_dry_run() {
    test_log "Testing --remove CLI flag with preset and dry-run..."
    local out
    out=$(bash "${PROJECT_ROOT}/install.sh" --distro debian --preset top10 --remove --dry-run 2>&1)
    echo "${out}" | grep -q "Selected preset 'top10'" || { test_log "FAIL: preset top10 not selected: ${out}"; return 1; }
    echo "${out}" | grep -q "apt purge -y" || { test_log "FAIL: missing apt purge command: ${out}"; return 1; }
    echo "${out}" | grep -q "Successfully uninstalled: 10" || { test_log "FAIL: preset uninstall count incorrect: ${out}"; return 1; }
    test_log "PASS: --remove CLI flag with preset verified"
}

test_uninstall_help_option() {
    test_log "Testing --uninstall is documented in help..."
    local out
    out=$(bash "${PROJECT_ROOT}/install.sh" --help 2>&1)
    echo "${out}" | grep -q -- "--uninstall" || { test_log "FAIL: --uninstall missing from help: ${out}"; return 1; }
    echo "${out}" | grep -q -- "--remove" || { test_log "FAIL: --remove missing from help: ${out}"; return 1; }
    test_log "PASS: --uninstall and --remove documented in help"
}

test_uninstall_print_summary_set_e() {
    test_log "Testing print_uninstall_summary under set -euo pipefail..."
    local out
    if ! out=$(bash -c 'set -euo pipefail; source lib/utils.sh; source lib/installer.sh; DRY_RUN=false; TOOLS_TO_INSTALL=("tool1" "tool2" "tool3"); INSTALL_RESULTS=("REMOVED:tool1" "NOT_INSTALLED:tool2" "FAILED:tool3"); print_uninstall_summary 2>&1'); then
        test_log "FAIL: print_uninstall_summary crashed under set -euo pipefail: ${out}"
        return 1
    fi
    echo "${out}" | grep -q "Successfully uninstalled: 1" || { test_log "FAIL: print_uninstall_summary removed count missing: ${out}"; return 1; }
    echo "${out}" | grep -q "Not installed (skipped): 1" || { test_log "FAIL: print_uninstall_summary not installed count missing: ${out}"; return 1; }
    echo "${out}" | grep -q "Failed to uninstall: 1" || { test_log "FAIL: print_uninstall_summary failed count missing: ${out}"; return 1; }
    test_log "PASS: print_uninstall_summary works cleanly under set -euo pipefail"
}

test_config_file_loading() {
    test_log "Testing persistent configuration file loading..."
    local tmp_cfg="/tmp/test-kali-config-load.conf"
    cat << 'EOF' > "${tmp_cfg}"
distro = arch
preset = top10
enable_blackarch = true
install_deps = false
dry_run = true
EOF
    local out
    out=$(bash "${PROJECT_ROOT}/install.sh" --config "${tmp_cfg}" 2>&1)
    rm -f "${tmp_cfg}"
    echo "${out}" | grep -q "Config file: ${tmp_cfg}" || { test_log "FAIL: config file not logged: ${out}"; return 1; }
    echo "${out}" | grep -q "Detected distribution: arch" || { test_log "FAIL: distro not set from config: ${out}"; return 1; }
    echo "${out}" | grep -q "Selected preset 'top10'" || { test_log "FAIL: preset not set from config: ${out}"; return 1; }
    echo "${out}" | grep -q "Dependency auto-installation skipped (--no-deps)" || { test_log "FAIL: install_deps=false not applied: ${out}"; return 1; }
    echo "${out}" | grep -q "Dry run complete" || { test_log "FAIL: dry_run=true not applied: ${out}"; return 1; }
    test_log "PASS: configuration file loading verified"
}

test_config_cli_override() {
    test_log "Testing CLI argument override precedence over configuration file..."
    local tmp_cfg="/tmp/test-kali-config-override.conf"
    cat << 'EOF' > "${tmp_cfg}"
distro = debian
preset = top10
install_deps = false
dry_run = true
EOF
    local out
    out=$(bash "${PROJECT_ROOT}/install.sh" --config "${tmp_cfg}" --distro arch --preset web --dry-run 2>&1)
    rm -f "${tmp_cfg}"
    echo "${out}" | grep -q "Detected distribution: arch" || { test_log "FAIL: CLI --distro arch did not override config debian: ${out}"; return 1; }
    echo "${out}" | grep -q "Selected preset 'web'" || { test_log "FAIL: CLI --preset web did not override config top10: ${out}"; return 1; }
    test_log "PASS: CLI arguments take precedence over config file"
}

test_custom_config_flag() {
    test_log "Testing --config flag error handling and equal syntax..."
    local out_missing
    if out_missing=$(bash "${PROJECT_ROOT}/install.sh" --config /tmp/nonexistent-config-file.conf 2>&1); then
        test_log "FAIL: expected error for nonexistent config file: ${out_missing}"
        return 1
    fi
    echo "${out_missing}" | grep -q "Configuration file not found" || { test_log "FAIL: missing error message: ${out_missing}"; return 1; }

    local out_no_arg
    if out_no_arg=$(bash "${PROJECT_ROOT}/install.sh" --config 2>&1); then
        test_log "FAIL: expected error for --config without argument: ${out_no_arg}"
        return 1
    fi
    echo "${out_no_arg}" | grep -q "Option --config requires an argument" || { test_log "FAIL: missing argument error message: ${out_no_arg}"; return 1; }

    local tmp_cfg="/tmp/test-kali-config-equal.conf"
    cat << 'EOF' > "${tmp_cfg}"
distro = arch
dry_run = true
tools = nmap
EOF
    local out_eq
    out_eq=$(bash "${PROJECT_ROOT}/install.sh" --config="${tmp_cfg}" 2>&1)
    rm -f "${tmp_cfg}"
    echo "${out_eq}" | grep -q "Selected tools: nmap" || { test_log "FAIL: --config=file failed to load: ${out_eq}"; return 1; }
    test_log "PASS: --config flag error handling and --config=syntax verified"
}

test_config_safe_parsing() {
    test_log "Testing safe key-value parsing, whitespace trimming, and quotes..."
    local tmp_cfg="/tmp/test-kali-config-safe.conf"
    cat << 'EOF' > "${tmp_cfg}"
# Full line comment
; Semicolon comment

  distro   =   "arch"   # inline comment with quotes
  preset   =   'top10'  ; inline semicolon comment
  log_file =   /tmp/safe-kali-test.log
  enable-blackarch = true
  # Attempt malicious command injection (must remain literal string)
  tools = `echo bad_command`
EOF
    (
        load_config_file "${tmp_cfg}"
        [[ "${FORCE_DISTRO}" == "arch" ]] || exit 1
        [[ "${SELECTED_PRESET}" == "top10" ]] || exit 1
        [[ "${LOG_FILE}" == "/tmp/safe-kali-test.log" ]] || exit 1
        [[ "${ENABLE_BLACKARCH}" == "true" ]] || exit 1
        [[ "${SELECTED_TOOLS[0]}" == "\`echo bad_command\`" ]] || exit 1
    )
    local ret=$?
    rm -f "${tmp_cfg}"
    [[ ${ret} -eq 0 ]] || { test_log "FAIL: safe parsing assertions failed"; return 1; }
    test_log "PASS: safe key-value parsing, trimming, quotes, and injection safety verified"
}

test_ci_and_docker_automation() {
    test_log "Testing CI workflow, Dockerfile, compose, and runner scripts..."
    
    local ci_file="${PROJECT_ROOT}/.github/workflows/ci.yml"
    [[ -f "${ci_file}" ]] || { test_log "FAIL: .github/workflows/ci.yml missing"; return 1; }
    grep -q "archlinux:latest" "${ci_file}" || { test_log "FAIL: ci.yml missing archlinux"; return 1; }
    grep -q "ubuntu:24.04" "${ci_file}" || { test_log "FAIL: ci.yml missing ubuntu"; return 1; }
    grep -q "debian:bookworm" "${ci_file}" || { test_log "FAIL: ci.yml missing debian"; return 1; }
    grep -q "fedora:40" "${ci_file}" || { test_log "FAIL: ci.yml missing fedora"; return 1; }
    grep -q "alpine:latest" "${ci_file}" || { test_log "FAIL: ci.yml missing alpine"; return 1; }
    grep -q "opensuse/tumbleweed:latest" "${ci_file}" || { test_log "FAIL: ci.yml missing opensuse"; return 1; }
    
    local dockerfile="${PROJECT_ROOT}/Dockerfile"
    [[ -f "${dockerfile}" ]] || { test_log "FAIL: Dockerfile missing"; return 1; }
    grep -q "ARG BASE_IMAGE=" "${dockerfile}" || { test_log "FAIL: Dockerfile missing BASE_IMAGE arg"; return 1; }
    grep -q "ENTRYPOINT" "${dockerfile}" || { test_log "FAIL: Dockerfile missing ENTRYPOINT"; return 1; }
    grep -q "kali" "${dockerfile}" || { test_log "FAIL: Dockerfile missing non-root kali user"; return 1; }
    
    local compose_file="${PROJECT_ROOT}/docker-compose.yml"
    [[ -f "${compose_file}" ]] || { test_log "FAIL: docker-compose.yml missing"; return 1; }
    grep -q "arch:" "${compose_file}" || { test_log "FAIL: docker-compose.yml missing arch service"; return 1; }
    grep -q "ubuntu:" "${compose_file}" || { test_log "FAIL: docker-compose.yml missing ubuntu service"; return 1; }
    
    local runner_script="${PROJECT_ROOT}/scripts/docker-test.sh"
    [[ -f "${runner_script}" ]] || { test_log "FAIL: scripts/docker-test.sh missing"; return 1; }
    [[ -x "${runner_script}" ]] || { test_log "FAIL: scripts/docker-test.sh not executable"; return 1; }
    
    local runner_help
    runner_help=$("${runner_script}" --help 2>&1)
    echo "${runner_help}" | grep -q "Usage: docker-test.sh" || { test_log "FAIL: docker-test.sh --help failed: ${runner_help}"; return 1; }
    
    test_log "PASS: CI workflow, Dockerfile, compose, and runner scripts verified"
}

test_bbs_banner_rendering() {
    test_log "Testing Concept A ASCII banner rendering..."
    local out
    out=$(bash -c "source '${PROJECT_ROOT}/lib/utils.sh'; source '${PROJECT_ROOT}/lib/packages.sh'; DISTRO='cachyos'; DISTRO_FAMILY='arch'; PACKAGE_MANAGER='pacman'; ENABLE_BLACKARCH='true'; print_banner" 2>&1)
    echo "${out}" | grep -q "OFFENSIVE SECURITY TOOLSET" || { test_log "FAIL: banner missing OFFENSIVE SECURITY TOOLSET: ${out}"; return 1; }
    echo "${out}" | grep -q "OS: cachyos" || { test_log "FAIL: banner missing OS: cachyos: ${out}"; return 1; }
    echo "${out}" | grep -q "PkgMgr: pacman" || { test_log "FAIL: banner missing PkgMgr: pacman: ${out}"; return 1; }
    echo "${out}" | grep -q "BlackArch: Enabled" || { test_log "FAIL: banner missing BlackArch: Enabled: ${out}"; return 1; }
    echo "${out}" | grep -q "Tools: 171 Total" || { test_log "FAIL: banner missing Tools count: ${out}"; return 1; }
    test_log "PASS: Concept A ASCII banner rendering verified"
}

test_bbs_menu_non_interactive_fallback() {
    test_log "Testing BBS menu non-interactive fallback when stdin is piped..."
    local out
    out=$(bash -c "source '${PROJECT_ROOT}/lib/utils.sh'; source '${PROJECT_ROOT}/lib/packages.sh'; source '${PROJECT_ROOT}/lib/menu.sh'; echo 'q' | bbs_main_menu" 2>&1)
    echo "${out}" | grep -q "MAIN SELECTION MENU" || { test_log "FAIL: bbs_main_menu did not render menu: ${out}"; return 1; }
    echo "${out}" | grep -q "Exiting Kali Tools Installer" || { test_log "FAIL: bbs_main_menu quit option failed: ${out}"; return 1; }
    test_log "PASS: BBS menu non-interactive fallback verified"
}

test_no_tui_flag() {
    test_log "Testing --no-tui and --plain CLI flags..."
    local out
    out=$(bash "${PROJECT_ROOT}/install.sh" --help 2>&1)
    echo "${out}" | grep -q -- "--no-tui" || { test_log "FAIL: --no-tui missing from help: ${out}"; return 1; }
    echo "${out}" | grep -q -- "--plain" || { test_log "FAIL: --plain missing from help: ${out}"; return 1; }
    
    local out_notui
    out_notui=$(bash "${PROJECT_ROOT}/install.sh" --distro arch --preset top10 --no-tui --dry-run 2>&1)
    echo "${out_notui}" | grep -q "Selected preset 'top10'" || { test_log "FAIL: --no-tui run failed: ${out_notui}"; return 1; }
    test_log "PASS: --no-tui and --plain flags verified"
}

run_tests() {
    test_log "=== Starting Kali Tools Installer Tests ==="
    test_log "Test log: ${TEST_LOG}"
    
    local failed=0
    
    test_detect_distro || ((failed+=1))
    test_utils_standalone_source || ((failed+=1))
    test_invalid_option_handling || ((failed+=1))
    test_load_tool_list || ((failed+=1))
    test_column_parsing_void_pkg || ((failed+=1))
    test_prompt_yes_no_default || ((failed+=1))
    test_dry_run_unprivileged || ((failed+=1))
    test_precheck_execution || ((failed+=1))
    test_precheck_with_dry_run || ((failed+=1))
    test_get_categories || ((failed+=1))
    test_get_tools_in_category || ((failed+=1))
    test_get_distro_pkg_name || ((failed+=1))
    test_in_memory_package_cache || ((failed+=1))
    test_multiple_distro_mappings || ((failed+=1))
    test_arch_package_completeness || ((failed+=1))
    test_build_from_source_recipe || ((failed+=1))
    test_validate_tool || ((failed+=1))
    test_validate_category || ((failed+=1))
    test_list_all_tools || ((failed+=1))
    test_log_file_no_ansi || ((failed+=1))
    test_cli_arg_validation || ((failed+=1))
    test_print_summary_set_e || ((failed+=1))
    test_case_insensitive_distro || ((failed+=1))
    test_mocked_os_release_distros || ((failed+=1))
    test_blackarch_setup_dry_run || ((failed+=1))
    test_presets_definition || ((failed+=1))
    test_preset_cli_dry_run || ((failed+=1))
    test_preset_precheck || ((failed+=1))
    test_preset_validation || ((failed+=1))
    test_tool_deps_cache || ((failed+=1))
    test_get_all_deps_for_tools || ((failed+=1))
    test_resolve_dep_pkg || ((failed+=1))
    test_build_prerequisites || ((failed+=1))
    test_dependency_resolution_cli || ((failed+=1))
    test_uninstall_cli_dry_run || ((failed+=1))
    test_uninstall_preset_dry_run || ((failed+=1))
    test_uninstall_help_option || ((failed+=1))
    test_uninstall_print_summary_set_e || ((failed+=1))
    test_config_file_loading || ((failed+=1))
    test_config_cli_override || ((failed+=1))
    test_custom_config_flag || ((failed+=1))
    test_config_safe_parsing || ((failed+=1))
    test_ci_and_docker_automation || ((failed+=1))
    test_bbs_banner_rendering || ((failed+=1))
    test_bbs_menu_non_interactive_fallback || ((failed+=1))
    test_no_tui_flag || ((failed+=1))
    
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