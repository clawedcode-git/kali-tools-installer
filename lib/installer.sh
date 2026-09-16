#!/usr/bin/env bash
set -euo pipefail

parse_args() {
    declare -g FORCE_DISTRO="${FORCE_DISTRO:-}"
    declare -ga SELECTED_CATEGORIES
    declare -ga SELECTED_TOOLS
    declare -g DRY_RUN="${DRY_RUN:-false}"
    declare -g ASSUME_YES="${ASSUME_YES:-false}"
    declare -g SKIP_UPDATE="${SKIP_UPDATE:-false}"
    declare -g LIST_INSTALLED="${LIST_INSTALLED:-false}"
    declare -g SHOW_HELP="${SHOW_HELP:-false}"
    declare -g PRECHECK="${PRECHECK:-false}"
    declare -g ENABLE_BLACKARCH="${ENABLE_BLACKARCH:-false}"
    declare -g SELECTED_PRESET="${SELECTED_PRESET:-}"
    declare -g INSTALL_DEPS="${INSTALL_DEPS:-true}"
    declare -g UNINSTALL="${UNINSTALL:-false}"
    declare -g CONFIG_FILE="${CONFIG_FILE:-}"
    declare -g NO_TUI="${NO_TUI:-false}"
    declare -g EXPORT_REPORT_FILE="${EXPORT_REPORT_FILE:-}"
    declare -g UPDATE_MODE="${UPDATE_MODE:-false}"
    declare -g DIFF_MODE="${DIFF_MODE:-false}"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --distro)
                if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
                    error "Option $1 requires an argument"
                    print_help
                    exit 1
                fi
                FORCE_DISTRO="${2,,}"
                export FORCE_DISTRO
                shift 2
                ;;
            --categories)
                if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
                    error "Option $1 requires an argument"
                    print_help
                    exit 1
                fi
                local sanitized_cats="${2//,/ }"
                read -ra SELECTED_CATEGORIES <<< "${sanitized_cats}"
                SELECTED_PRESET=""
                SELECTED_TOOLS=()
                shift 2
                ;;
            --tools)
                if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
                    error "Option $1 requires an argument"
                    print_help
                    exit 1
                fi
                local sanitized_tools="${2//,/ }"
                read -ra SELECTED_TOOLS <<< "${sanitized_tools}"
                SELECTED_PRESET=""
                SELECTED_CATEGORIES=()
                shift 2
                ;;
            --preset)
                if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
                    error "Option $1 requires an argument"
                    print_help
                    exit 1
                fi
                SELECTED_PRESET="${2,,}"
                SELECTED_CATEGORIES=()
                SELECTED_TOOLS=()
                shift 2
                ;;
            --config)
                if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
                    error "Option $1 requires an argument"
                    print_help
                    exit 1
                fi
                if [[ ! -f "$2" ]]; then
                    error "Configuration file not found: $2"
                    exit 1
                fi
                CONFIG_FILE="$2"
                shift 2
                ;;
            --config=*)
                local cfg="${1#--config=}"
                if [[ -z "${cfg}" ]]; then
                    error "Option --config requires an argument"
                    print_help
                    exit 1
                fi
                if [[ ! -f "${cfg}" ]]; then
                    error "Configuration file not found: ${cfg}"
                    exit 1
                fi
                CONFIG_FILE="${cfg}"
                shift
                ;;
            --yes|-y)
                ASSUME_YES=true
                export ASSUME_YES
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                export DRY_RUN
                shift
                ;;
            --no-update)
                SKIP_UPDATE=true
                export SKIP_UPDATE
                shift
                ;;
            --no-deps|--skip-deps)
                INSTALL_DEPS=false
                shift
                ;;
            --uninstall|--remove)
                UNINSTALL=true
                shift
                ;;
            --log-file)
                if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
                    error "Option $1 requires an argument"
                    print_help
                    exit 1
                fi
                LOG_FILE="$2"
                export LOG_FILE
                shift 2
                ;;
            --list-installed)
                LIST_INSTALLED=true
                shift
                ;;
            --precheck)
                PRECHECK=true
                shift
                ;;
            --enable-blackarch)
                ENABLE_BLACKARCH=true
                shift
                ;;
            --no-tui|--plain)
                NO_TUI=true
                export NO_TUI
                shift
                ;;
            --update)
                UPDATE_MODE=true
                export UPDATE_MODE
                shift
                ;;
            --diff)
                DIFF_MODE=true
                export DIFF_MODE
                shift
                ;;
            --method-override|--method)
                if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
                    error "Option $1 requires an argument (e.g. tool:method)"
                    print_help
                    exit 1
                fi
                local -a pairs=()
                IFS=',' read -ra pairs <<< "$2"
                for pair in "${pairs[@]}"; do
                    if [[ "${pair}" == *":"* ]]; then
                        local t_name="${pair%%:*}"
                        local m_name="${pair#*:}"
                        TOOL_METHOD_OVERRIDES["${t_name}"]="${m_name}"
                    fi
                done
                shift 2
                ;;
            --method-override=*|--method=*)
                local val="${1#*=}"
                if [[ -z "${val}" ]]; then
                    error "Option --method-override requires an argument (e.g. tool:method)"
                    print_help
                    exit 1
                fi
                local -a pairs=()
                IFS=',' read -ra pairs <<< "${val}"
                for pair in "${pairs[@]}"; do
                    if [[ "${pair}" == *":"* ]]; then
                        local t_name="${pair%%:*}"
                        local m_name="${pair#*:}"
                        TOOL_METHOD_OVERRIDES["${t_name}"]="${m_name}"
                    fi
                done
                shift
                ;;
            --export-report)
                if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
                    error "Option $1 requires a file path argument"
                    print_help
                    exit 1
                fi
                EXPORT_REPORT_FILE="$2"
                export EXPORT_REPORT_FILE
                shift 2
                ;;
            --export-report=*)
                EXPORT_REPORT_FILE="${1#--export-report=}"
                if [[ -z "${EXPORT_REPORT_FILE}" ]]; then
                    error "Option --export-report requires a file path"
                    print_help
                    exit 1
                fi
                export EXPORT_REPORT_FILE
                shift
                ;;
            --help|-h)
                SHOW_HELP=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                print_help
                exit 1
                ;;
        esac
    done
    
    export FORCE_DISTRO ASSUME_YES DRY_RUN SKIP_UPDATE LOG_FILE PRECHECK ENABLE_BLACKARCH SELECTED_PRESET INSTALL_DEPS UNINSTALL CONFIG_FILE NO_TUI LIST_INSTALLED EXPORT_REPORT_FILE UPDATE_MODE DIFF_MODE
}

print_help() {
    load_tool_list >/dev/null 2>&1 || true
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
    --distro <name>         Force distribution (arch, debian, fedora, slackware, opensuse, gentoo, alpine, void)
    --preset <name>         Install curated preset (top10, default, headless, web, wireless, passwords)
    --categories <list>     Comma-separated categories to install
    --tools <list>          Comma-separated specific tools to install
    --config <path>         Load custom configuration file
    --yes, -y               Skip confirmations
    --dry-run               Show packages without installing
    --no-update             Skip package database update
    --no-deps               Skip automatic dependency installation
    --uninstall, --remove   Uninstall targeted tools/preset/categories
    --update                Update all currently installed Kali tools
    --diff                  Compare installed tools vs selected scope (preset/category/all)
    --method-override <t:m> Override install method for specific tools (e.g. wfuzz:pip,nmap:source)
    --enable-blackarch      Enable BlackArch repository on Arch/CachyOS
    --no-tui, --plain       Disable ASCII banner styling and BBS interactive menus
    --log-file <path>       Custom log location
    --list-installed        Display dashboard of installed Kali tools with version & method
    --precheck              Check package availability (official/AUR/pipx/BlackArch)
    --export-report <path>  Export availability/install report to JSON or CSV file
    --help, -h              Show this help

Install tiers (Arch/CachyOS): official repos → AUR → pipx/pip → BlackArch → source build

Presets: $(get_presets | paste -sd, -)
Categories: $(get_categories | paste -sd, -)

Examples:
    sudo $(basename "$0")                                        # Interactive
    sudo $(basename "$0") --preset top10 --yes                  # Install Top 10 Kali tools
    sudo $(basename "$0") --preset headless --yes               # Install headless CLI tools
    sudo $(basename "$0") --config ~/.config/kali-installer/config  # Custom config file
    sudo $(basename "$0") --distro arch --yes                   # Non-interactive Arch
    sudo $(basename "$0") --distro arch --enable-blackarch      # With BlackArch repos
    sudo $(basename "$0") --distro slackware --yes              # Non-interactive Slackware
    sudo $(basename "$0") --precheck --distro arch              # Check package availability
    sudo $(basename "$0") --precheck --export-report /tmp/report.json  # Export precheck as JSON
    sudo $(basename "$0") --list-installed                      # Installed tools dashboard
    sudo $(basename "$0") --diff --preset top10                 # Compare top10 vs installed
    sudo $(basename "$0") --update --dry-run                    # Preview updates for installed tools
    sudo $(basename "$0") --tools wfuzz --method-override wfuzz:pip --yes # Pin method
    sudo $(basename "$0") --categories web,vuln --yes
    sudo $(basename "$0") --tools nmap,metasploit-framework --dry-run
EOF
}


select_installation_scope() {
    if [[ -n "${SELECTED_PRESET:-}" ]]; then
        if ! validate_preset "${SELECTED_PRESET}"; then
            error "Unknown preset: ${SELECTED_PRESET}"
            error "Available presets: $(get_presets | paste -sd, -)"
            exit 1
        fi
        read -ra TOOLS_TO_INSTALL <<< "$(get_tools_in_preset "${SELECTED_PRESET}")"
        info "Selected preset '${SELECTED_PRESET}' (${#TOOLS_TO_INSTALL[@]} tools): ${TOOLS_TO_INSTALL[*]}"
        return
    fi
    
    if [[ ${#SELECTED_TOOLS[@]} -gt 0 ]]; then
        TOOLS_TO_INSTALL=("${SELECTED_TOOLS[@]}")
        info "Selected tools: ${TOOLS_TO_INSTALL[*]}"
        return
    fi
    
    if [[ ${#SELECTED_CATEGORIES[@]} -gt 0 ]]; then
        for cat in "${SELECTED_CATEGORIES[@]}"; do
            if ! validate_category "${cat}"; then
                error "Unknown category: ${cat}"
                exit 1
            fi
            local -a cat_tools=()
            read -ra cat_tools <<< "$(get_tools_in_category "${cat}")"
            TOOLS_TO_INSTALL+=("${cat_tools[@]}")
        done
        info "Selected categories: ${SELECTED_CATEGORIES[*]}"
        return
    fi
    
    if [[ -t 0 && "${NO_TUI:-false}" != "true" && "${ASSUME_YES:-false}" != "true" ]]; then
        if [[ "${UNINSTALL:-false}" == "true" ]]; then
            bbs_uninstall_menu
        else
            bbs_main_menu
        fi
        return
    fi
    
    print_banner
    echo
    local action_title="installation"
    [[ "${UNINSTALL:-false}" == "true" ]] && action_title="uninstallation"
    info "Select ${action_title} scope:"
    echo "  1) All Kali tools (~171 packages)"
    echo "  2) Tool presets (top10, default, headless, web, wireless, passwords)"
    echo "  3) Select categories"
    echo "  4) Select specific tools"
    echo
    
    local choice
    choice=$(prompt_select "Choose option:" "All tools" "Tool presets" "Select categories" "Select tools")
    
    case "${choice}" in
        "All tools")
            mapfile -t TOOLS_TO_INSTALL < <(list_all_tools)
            ;;
        "Tool presets")
            select_preset_interactive
            ;;
        "Select categories")
            select_categories_interactive
            ;;
        "Select tools")
            select_tools_interactive
            ;;
    esac
}

select_preset_interactive() {
    local presets=()
    mapfile -t presets < <(get_presets)
    echo "Available presets:"
    for i in "${!presets[@]}"; do
        local p="${presets[i]}"
        local desc
        desc=$(get_preset_description "${p}")
        local -a p_tools=()
        read -ra p_tools <<< "$(get_tools_in_preset "${p}")"
        echo "  $((i+1))) ${p} (${#p_tools[@]} tools) - ${desc}"
    done
    echo
    
    local choice
    choice=$(prompt_select "Choose preset:" "${presets[@]}")
    read -ra TOOLS_TO_INSTALL <<< "$(get_tools_in_preset "${choice}")"
    info "Selected preset '${choice}' (${#TOOLS_TO_INSTALL[@]} tools)"
}

select_categories_interactive() {
    local categories=()
    mapfile -t categories < <(get_categories)
    echo "Available categories:"
    for i in "${!categories[@]}"; do
        local -a cat_tools=()
        read -ra cat_tools <<< "${CATEGORY_TOOLS[${categories[i]}]:-}"
        local count=${#cat_tools[@]}
        echo "  $((i+1))) ${categories[i]} (${count} tools)"
    done
    echo
    
    local input
    read -rp "Enter category numbers (comma-separated, or 'all'): " input
    
    if [[ "${input,,}" == "all" ]]; then
        mapfile -t TOOLS_TO_INSTALL < <(list_all_tools)
        return
    fi
    
    IFS=',' read -ra selections <<< "${input}"
    for sel in "${selections[@]}"; do
        sel="${sel//[[:space:]]/}"
        if [[ "${sel}" =~ ^[0-9]+$ ]] && [[ ${sel} -ge 1 ]] && [[ ${sel} -le ${#categories[@]} ]]; then
            local cat="${categories[$((sel-1))]}"
            local -a cat_tools=()
            read -ra cat_tools <<< "$(get_tools_in_category "${cat}")"
            TOOLS_TO_INSTALL+=("${cat_tools[@]}")
        fi
    done
}

select_tools_interactive() {
    local all_tools=()
    mapfile -t all_tools < <(list_all_tools)
    echo "Available tools (first 50):"
    for i in "${!all_tools[@]}"; do
        [[ $i -ge 50 ]] && break
        local desc
        desc=$(get_tool_description "${all_tools[i]}")
        printf "  %3d) %-30s %s\n" $((i+1)) "${all_tools[i]}" "${desc}"
    done
    [[ ${#all_tools[@]} -gt 50 ]] && echo "  ... and $((${#all_tools[@]} - 50)) more"
    echo
    
    local input
    read -rp "Enter tool numbers (comma-separated): " input
    
    IFS=',' read -ra selections <<< "${input}"
    for sel in "${selections[@]}"; do
        sel="${sel//[[:space:]]/}"
        if [[ "${sel}" =~ ^[0-9]+$ ]] && [[ ${sel} -ge 1 ]] && [[ ${sel} -le ${#all_tools[@]} ]]; then
            TOOLS_TO_INSTALL+=("${all_tools[$((sel-1))]}")
        fi
    done
}

confirm_installation() {
    if [[ ${#TOOLS_TO_INSTALL[@]} -eq 0 ]]; then
        error "No tools selected for installation"
        exit 1
    fi
    
    info "Tools to install (${#TOOLS_TO_INSTALL[@]}):"
    for tool in "${TOOLS_TO_INSTALL[@]}"; do
        local pkg
        pkg=$(get_distro_pkg_name "${tool}")
        if [[ -n "${pkg}" ]]; then
            echo "  ${tool} -> ${pkg}"
        else
            warn "  ${tool} -> NO PACKAGE MAPPING FOR ${DISTRO_FAMILY}"
        fi
    done
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "Planning installation in dry-run mode..."
        return 0
    fi
    
    if [[ "${DISTRO_FAMILY}" == "arch" && "${ENABLE_BLACKARCH}" != "true" ]]; then
        if ! grep -q "\[blackarch\]" /etc/pacman.conf 2>/dev/null; then
            if [[ "${ASSUME_YES}" != "true" ]]; then
                if prompt_yes_no "Enable BlackArch repository for thousands of additional tools?" "n"; then
                    ENABLE_BLACKARCH=true
                fi
            fi
        fi
    fi
    
    local proceed=false
    if [[ -t 0 && "${NO_TUI:-false}" != "true" && "${ASSUME_YES:-false}" != "true" ]]; then
        if bbs_confirm_dialog "Installation" "${#TOOLS_TO_INSTALL[@]} tools"; then
            proceed=true
        fi
    else
        if prompt_yes_no "Proceed with installation?"; then
            proceed=true
        fi
    fi
    if [[ "${proceed}" != "true" ]]; then
        info "Installation cancelled by user"
        exit 0
    fi
}

confirm_uninstallation() {
    if [[ ${#TOOLS_TO_INSTALL[@]} -eq 0 ]]; then
        error "No tools targeted for uninstallation"
        exit 1
    fi
    
    info "Targeting ${#TOOLS_TO_INSTALL[@]} tools for uninstallation..."
    local installed_count=0
    for tool in "${TOOLS_TO_INSTALL[@]}"; do
        local pkg
        pkg=$(get_distro_pkg_name "${tool}")
        local status="not installed"
        if [[ -n "${pkg}" ]] && is_pkg_installed "${pkg}"; then
            status="installed (${pkg})"
            ((installed_count+=1))
        elif [[ -f "/usr/local/bin/${tool}" || -L "/usr/local/bin/${tool}" || -d "/opt/${tool}" ]]; then
            status="installed (source)"
            ((installed_count+=1))
        fi
        debug "  ${tool}: ${status}"
    done
    
    info "${installed_count} of ${#TOOLS_TO_INSTALL[@]} targeted tools are currently installed."
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "Planning uninstallation in dry-run mode..."
        return 0
    fi
    
    if [[ "${ASSUME_YES}" != "true" ]]; then
        local proceed=false
        if [[ -t 0 && "${NO_TUI:-false}" != "true" ]]; then
            if bbs_confirm_dialog "Uninstallation" "${#TOOLS_TO_INSTALL[@]} targeted tools"; then
                proceed=true
            fi
        else
            if prompt_yes_no "Are you sure you want to uninstall these tools?" "n"; then
                proceed=true
            fi
        fi
        if [[ "${proceed}" != "true" ]]; then
            info "Uninstallation cancelled by user"
            exit 0
        fi
    fi
}

setup_blackarch() {
    if [[ "${DISTRO_FAMILY}" != "arch" ]]; then
        warn "BlackArch repository setup is only supported on Arch-based systems"
        return 1
    fi
    
    if grep -q "\[blackarch\]" /etc/pacman.conf 2>/dev/null; then
        info "BlackArch repository is already configured in /etc/pacman.conf"
        return 0
    fi
    
    info "Setting up BlackArch repository..."
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "[DRY RUN] curl -s -O https://blackarch.org/strap.sh"
        info "[DRY RUN] chmod +x strap.sh && ./strap.sh"
        return 0
    fi
    
    if [[ ${EUID} -ne 0 ]]; then
        error "Configuring BlackArch repository requires root privileges (run with sudo)"
        return 1
    fi
    
    local strap_tmp="/tmp/blackarch-strap-${UID:-0}"
    mkdir -p "${strap_tmp}"
    if curl -s -o "${strap_tmp}/strap.sh" https://blackarch.org/strap.sh; then
        chmod +x "${strap_tmp}/strap.sh"
        run_cmd "${strap_tmp}/strap.sh"
        rm -rf "${strap_tmp}"
        info "BlackArch repository configured successfully"
        return 0
    else
        error "Failed to download BlackArch strap.sh script"
        rm -rf "${strap_tmp}"
        return 1
    fi
}

update_package_db() {
    if [[ "${SKIP_UPDATE}" == "true" ]]; then
        info "Skipping package database update (--no-update)"
        return
    fi
    
    if [[ ${EUID} -ne 0 ]]; then
        warn "Running unprivileged; skipping package database update"
        return
    fi
    
    info "Updating package database..."
    case "${PACKAGE_MANAGER}" in
        pacman)
            run_cmd pacman -Sy --noconfirm
            ;;
        apt)
            run_cmd apt update
            ;;
        dnf)
            run_cmd dnf check-update || true
            ;;
        zypper)
            run_cmd zypper refresh
            ;;
        slackpkg)
            run_cmd slackpkg update gpg && run_cmd slackpkg update
            ;;
        emerge)
            run_cmd emerge --sync
            ;;
        apk)
            run_cmd apk update
            ;;
        xbps)
            run_cmd xbps-install -S
            ;;
    esac
}

get_aur_helper() {
    if command -v yay &>/dev/null; then
        echo "yay"
    elif command -v paru &>/dev/null; then
        echo "paru"
    else
        echo ""
    fi
}

run_aur_cmd() {
    local helper="$1"
    shift
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "[DRY RUN] ${helper} $*"
        return 0
    fi
    
    debug "Executing AUR helper (${helper}): $*"
    if [[ ${EUID} -eq 0 && -n "${SUDO_USER:-}" ]]; then
        sudo -u "${SUDO_USER}" "${helper}" "$@" 2>&1 | tee -a "${LOG_FILE}"
        return ${PIPESTATUS[0]}
    else
        "${helper}" "$@" 2>&1 | tee -a "${LOG_FILE}"
        return ${PIPESTATUS[0]}
    fi
}


# ---------------------------------------------------------------------------
# Tier helpers: pipx / BlackArch
# ---------------------------------------------------------------------------

get_pipx() {
    if command -v pipx &>/dev/null; then
        echo "pipx"
    elif command -v pip3 &>/dev/null; then
        echo "pip3"
    else
        echo ""
    fi
}

install_via_pipx() {
    local tool="$1"
    local pip_pkg="$2"
    [[ -z "${pip_pkg}" ]] && return 1
    
    local pip_cmd
    pip_cmd=$(get_pipx)
    [[ -z "${pip_cmd}" ]] && { warn "No pipx or pip3 found; cannot install ${tool} via pip"; return 1; }
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        if [[ "${pip_cmd}" == "pipx" ]]; then
            info "[DRY RUN] pipx install ${pip_pkg}"
        else
            info "[DRY RUN] pip3 install --user ${pip_pkg}"
        fi
        success "Installed (dry run): ${tool} (${pip_pkg}) via ${pip_cmd}"
        INSTALL_RESULTS+=("SUCCESS:${tool} (pipx/pip)")
        return 0
    fi
    
    local pip_res=0
    info "Installing ${tool} (${pip_pkg}) via ${pip_cmd}..."
    if [[ "${pip_cmd}" == "pipx" ]]; then
        pipx install "${pip_pkg}" 2>&1 | tee -a "${LOG_FILE}" || pip_res=$?
    else
        # PEP 668: try --break-system-packages first, fall back to --user
        local pip_flags=()
        if pip3 install --help 2>/dev/null | grep -q -- '--break-system-packages'; then
            pip_flags=(--break-system-packages)
        else
            pip_flags=(--user)
        fi
        pip3 install "${pip_flags[@]}" "${pip_pkg}" 2>&1 | tee -a "${LOG_FILE}" || pip_res=$?
    fi
    
    if [[ ${pip_res} -eq 0 ]]; then
        success "Installed: ${tool} (${pip_pkg}) via ${pip_cmd}"
        INSTALL_RESULTS+=("SUCCESS:${tool} (pipx/pip)")
        return 0
    fi
    warn "pip/pipx install of ${tool} (${pip_pkg}) failed (exit ${pip_res})"
    return 1
}

auto_enable_blackarch_if_needed() {
    # Returns 0 if BlackArch is already enabled or we successfully enable it
    if grep -q '\[blackarch\]' /etc/pacman.conf 2>/dev/null; then
        return 0
    fi
    
    if [[ "${ENABLE_BLACKARCH}" == "true" ]]; then
        setup_blackarch
        return $?
    fi
    
    # Prompt user once (or auto-accept with --yes)
    if [[ "${ASSUME_YES}" == "true" ]]; then
        warn "Tool requires BlackArch repo — enabling automatically (--yes)"
        ENABLE_BLACKARCH=true
        setup_blackarch
        return $?
    fi
    
    if [[ -t 0 && "${NO_TUI:-false}" != "true" ]]; then
        if bbs_confirm_dialog "BlackArch Required" "Enable BlackArch repo to install this tool?"; then
            ENABLE_BLACKARCH=true
            setup_blackarch
            return $?
        fi
    else
        if prompt_yes_no "Tool requires BlackArch repo. Enable it now?" "y"; then
            ENABLE_BLACKARCH=true
            setup_blackarch
            return $?
        fi
    fi
    
    warn "BlackArch repo not enabled — skipping BlackArch-only tool"
    return 1
}

get_tool_method_override() {
    local tool="$1"
    echo "${TOOL_METHOD_OVERRIDES["${tool}"]:-}"
}

# ---------------------------------------------------------------------------
# install_package — 5-tier fallback: native → AUR → pipx → BlackArch → source
# ---------------------------------------------------------------------------

install_package() {
    local tool="$1"
    local pkg_name
    pkg_name=$(get_distro_pkg_name "${tool}")
    
    local result=0
    
    # ── Method Override Check ──────────────────────────────────────────────
    local method_override
    method_override=$(get_tool_method_override "${tool}")
    if [[ -n "${method_override}" ]]; then
        info "Applying method override for ${tool}: ${method_override}"
        case "${method_override,,}" in
            native|pacman|apt|dnf|zypper|apk|xbps|emerge|slackpkg)
                if [[ -n "${pkg_name}" ]]; then
                    local res=0
                    case "${PACKAGE_MANAGER}" in
                        pacman) run_cmd pacman -S --noconfirm --needed "${pkg_name}" || res=$? ;;
                        apt) run_cmd apt install -y "${pkg_name}" || res=$? ;;
                        dnf) run_cmd dnf install -y "${pkg_name}" || res=$? ;;
                        zypper) run_cmd zypper install -y "${pkg_name}" || res=$? ;;
                        slackpkg) run_cmd slackpkg install "${pkg_name}" || res=$? ;;
                        emerge) run_cmd emerge "${pkg_name}" || res=$? ;;
                        apk) run_cmd apk add "${pkg_name}" || res=$? ;;
                        xbps) run_cmd xbps-install -y "${pkg_name}" || res=$? ;;
                        *) res=1 ;;
                    esac
                    if [[ ${res} -eq 0 ]]; then
                        success "Installed: ${tool} (${pkg_name}) [override: native]"
                        INSTALL_RESULTS+=("SUCCESS:${tool} (native override)")
                        return 0
                    fi
                fi
                ;;
            aur)
                local aur_helper
                aur_helper=$(get_aur_helper)
                if [[ -n "${aur_helper}" && -n "${pkg_name}" ]]; then
                    if run_aur_cmd "${aur_helper}" -S --noconfirm --needed "${pkg_name}"; then
                        success "Installed: ${tool} (${pkg_name}) via ${aur_helper} [override: aur]"
                        INSTALL_RESULTS+=("SUCCESS:${tool} (aur override)")
                        return 0
                    fi
                fi
                ;;
            pip|pipx|pypi)
                local pip_pkg
                pip_pkg=$(get_tool_pip_pkg "${tool}")
                [[ -z "${pip_pkg}" ]] && pip_pkg="${tool}"
                if install_via_pipx "${tool}" "${pip_pkg}"; then
                    return 0
                fi
                ;;
            blackarch)
                local ba_pkg
                ba_pkg=$(get_tool_blackarch_pkg "${tool}")
                [[ -z "${ba_pkg}" ]] && ba_pkg="${pkg_name}"
                if [[ -n "${ba_pkg}" ]] && auto_enable_blackarch_if_needed; then
                    if run_cmd pacman -S --noconfirm --needed "${ba_pkg}"; then
                        success "Installed: ${tool} (${ba_pkg}) via BlackArch [override: blackarch]"
                        INSTALL_RESULTS+=("SUCCESS:${tool} (blackarch override)")
                        return 0
                    fi
                fi
                ;;
            source|git|go|cmake|make)
                if build_from_source "${tool}"; then
                    success "Installed from source: ${tool} [override: source]"
                    INSTALL_RESULTS+=("SUCCESS:${tool} (source override)")
                    return 0
                fi
                ;;
            *)
                warn "Unknown method override '${method_override}' for ${tool}"
                ;;
        esac
        error "Failed: ${tool} (method override '${method_override}' failed)"
        INSTALL_RESULTS+=("FAILED:${tool} (${method_override} override)")
        return 1
    fi
    
    # ── Tier 1: Native package manager ─────────────────────────────────────
    if [[ -n "${pkg_name}" ]]; then
        debug "Installing ${tool} (${pkg_name}) via ${PACKAGE_MANAGER}"
        case "${PACKAGE_MANAGER}" in
            pacman)
                run_cmd pacman -S --noconfirm --needed "${pkg_name}" || result=$?
                ;;
            apt)
                run_cmd apt install -y "${pkg_name}" || result=$?
                ;;
            dnf)
                run_cmd dnf install -y "${pkg_name}" || result=$?
                ;;
            zypper)
                run_cmd zypper install -y "${pkg_name}" || result=$?
                ;;
            slackpkg)
                run_cmd slackpkg install "${pkg_name}" || result=$?
                ;;
            emerge)
                run_cmd emerge "${pkg_name}" || result=$?
                ;;
            apk)
                run_cmd apk add "${pkg_name}" || result=$?
                ;;
            xbps)
                run_cmd xbps-install -y "${pkg_name}" || result=$?
                ;;
            *)
                error "Unknown package manager: ${PACKAGE_MANAGER}"
                result=1
                ;;
        esac
    else
        result=1
    fi
    
    [[ ${result} -eq 0 ]] && { success "Installed: ${tool} (${pkg_name})"; INSTALL_RESULTS+=("SUCCESS:${tool}"); return 0; }
    
    # ── Tier 2: AUR helper (Arch only) ─────────────────────────────────────
    if [[ "${PACKAGE_MANAGER}" == "pacman" && -n "${pkg_name}" ]]; then
        local aur_helper
        aur_helper=$(get_aur_helper)
        if [[ -n "${aur_helper}" ]]; then
            info "Attempting installation of ${tool} (${pkg_name}) via AUR (${aur_helper})..."
            local aur_res=0
            run_aur_cmd "${aur_helper}" -S --noconfirm --needed "${pkg_name}" || aur_res=$?
            if [[ ${aur_res} -eq 0 ]]; then
                success "Installed: ${tool} (${pkg_name}) via ${aur_helper}"
                INSTALL_RESULTS+=("SUCCESS:${tool}")
                return 0
            fi
        fi
    fi
    
    # ── Tier 3: pipx / pip3 ────────────────────────────────────────────────
    local pip_pkg
    pip_pkg=$(get_tool_pip_pkg "${tool}")
    if [[ -n "${pip_pkg}" ]]; then
        if install_via_pipx "${tool}" "${pip_pkg}"; then
            return 0
        fi
    fi
    
    # ── Tier 4: BlackArch repo (Arch only) ─────────────────────────────────
    if [[ "${PACKAGE_MANAGER}" == "pacman" ]]; then
        local ba_pkg
        ba_pkg=$(get_tool_blackarch_pkg "${tool}")
        if [[ -n "${ba_pkg}" ]]; then
            if auto_enable_blackarch_if_needed; then
                info "Installing ${tool} (${ba_pkg}) from BlackArch..."
                local ba_res=0
                run_cmd pacman -S --noconfirm --needed "${ba_pkg}" || ba_res=$?
                if [[ ${ba_res} -eq 0 ]]; then
                    success "Installed: ${tool} (${ba_pkg}) via BlackArch"
                    INSTALL_RESULTS+=("SUCCESS:${tool} (blackarch)")
                    return 0
                fi
                warn "BlackArch install of ${tool} (${ba_pkg}) failed"
            fi
        fi
    fi
    
    # ── Tier 5: Source build ────────────────────────────────────────────────
    local build_chk
    build_chk=$(check_build_from_source "${tool}" "${pkg_name}" || true)
    if [[ "${build_chk}" == BUILDABLE:* ]]; then
        info "Attempting source build fallback for ${tool}..."
        if build_from_source "${tool}"; then
            success "Installed from source: ${tool}"
            INSTALL_RESULTS+=("SUCCESS:${tool} (source)")
            return 0
        fi
    fi
    
    # ── All tiers exhausted ─────────────────────────────────────────────────
    local pip_mapped ba_mapped
    pip_mapped=$(get_tool_pip_pkg "${tool}")
    ba_mapped=$(get_tool_blackarch_pkg "${tool}")
    if [[ -z "${pkg_name}" && -z "${pip_mapped}" && -z "${ba_mapped}" ]]; then
        warn "No package mapping for ${tool} on ${DISTRO_FAMILY}"
        INSTALL_RESULTS+=("SKIPPED:${tool} (no mapping)")
    else
        error "Failed: ${tool} — all install tiers exhausted"
        INSTALL_RESULTS+=("FAILED:${tool}")
    fi
    return 1
}


run_cmd() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "[DRY RUN] $*"
        return 0
    fi
    
    debug "Executing: $*"
    "$@" 2>&1 | tee -a "${LOG_FILE}"
    return ${PIPESTATUS[0]}
}

is_pkg_installed() {
    local pkg="$1"
    [[ -z "${pkg}" ]] && return 1
    
    case "${PACKAGE_MANAGER}" in
        pacman) pacman -Q "${pkg}" &>/dev/null ;;
        apt) dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q "ok installed" ;;
        dnf) rpm -q "${pkg}" &>/dev/null ;;
        zypper) rpm -q "${pkg}" &>/dev/null ;;
        apk) apk info -e "${pkg}" &>/dev/null ;;
        slackpkg)
            if [[ -d "/var/log/packages" ]]; then
                ls /var/log/packages/"${pkg}"-[0-9]* &>/dev/null
            else
                slackpkg search installed "${pkg}" 2>/dev/null | grep -q "^${pkg}"
            fi
            ;;
        emerge)
            qlist -I -e "${pkg}" &>/dev/null || equery which "${pkg}" &>/dev/null || ls -d /var/db/pkg/*/"${pkg}"-[0-9]* &>/dev/null 2>&1
            ;;
        xbps) xbps-query "${pkg}" &>/dev/null || xbps-query -s "${pkg}" &>/dev/null ;;
        *) return 1 ;;
    esac
}

install_dependencies() {
    local -a tools=("$@")
    if [[ "${INSTALL_DEPS:-true}" != "true" ]]; then
        info "Dependency auto-installation skipped (--no-deps)"
        return 0
    fi
    
    local -a all_deps=()
    mapfile -t all_deps < <(get_all_deps_for_tools "${tools[@]}")
    
    if [[ ${#all_deps[@]} -eq 0 ]]; then
        return 0
    fi
    
    info "Resolving dependencies for ${#tools[@]} tools..."
    local -a pkgs_to_install=()
    local -A seen_pkgs=()
    
    for dep in "${all_deps[@]}"; do
        local resolved_pkg
        resolved_pkg=$(resolve_dep_pkg "${dep}" "${DISTRO_FAMILY}")
        if [[ -n "${resolved_pkg}" ]]; then
            local -a split_pkgs=()
            IFS=',' read -ra split_pkgs <<< "${resolved_pkg}"
            for p in "${split_pkgs[@]}"; do
                p="${p#"${p%%[![:space:]]*}"}"
                p="${p%"${p##*[![:space:]]}"}"
                if [[ -n "${p}" && -z "${seen_pkgs["${p}"]:-}" ]]; then
                    seen_pkgs["${p}"]="1"
                    if ! is_pkg_installed "${p}"; then
                        pkgs_to_install+=("${p}")
                    else
                        debug "Dependency already installed: ${p}"
                    fi
                fi
            done
        fi
    done
    
    if [[ ${#pkgs_to_install[@]} -eq 0 ]]; then
        info "All runtime dependencies are already satisfied."
        return 0
    fi
    
    info "Installing ${#pkgs_to_install[@]} runtime dependencies: ${pkgs_to_install[*]}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "[DRY RUN] Would install dependencies: ${pkgs_to_install[*]}"
        return 0
    fi
    
    local res=0
    case "${PACKAGE_MANAGER}" in
        pacman) run_cmd pacman -S --noconfirm --needed "${pkgs_to_install[@]}" || res=$? ;;
        apt) run_cmd apt install -y "${pkgs_to_install[@]}" || res=$? ;;
        dnf) run_cmd dnf install -y "${pkgs_to_install[@]}" || res=$? ;;
        zypper) run_cmd zypper install -y "${pkgs_to_install[@]}" || res=$? ;;
        apk) run_cmd apk add "${pkgs_to_install[@]}" || res=$? ;;
        xbps) run_cmd xbps-install -y "${pkgs_to_install[@]}" || res=$? ;;
        emerge) run_cmd emerge "${pkgs_to_install[@]}" || res=$? ;;
        slackpkg)
            for p in "${pkgs_to_install[@]}"; do
                run_cmd slackpkg install "${p}" || res=$?
            done
            ;;
        *)
            warn "Unknown package manager for dependencies: ${PACKAGE_MANAGER}"
            res=1
            ;;
    esac
    
    if [[ ${res} -eq 0 ]]; then
        success "Dependencies installed successfully."
    else
        warn "Some dependencies failed to install (exit code ${res}). Continuing with tool installation..."
    fi
    return 0
}

run_installation() {
    if [[ "${ENABLE_BLACKARCH:-false}" == "true" && "${DISTRO_FAMILY}" == "arch" ]]; then
        setup_blackarch
    fi
    
    update_package_db
    
    install_dependencies "${TOOLS_TO_INSTALL[@]}"
    
    info "Starting installation of ${#TOOLS_TO_INSTALL[@]} tools..."
    
    local -a batch_pkgs=()
    local -A seen_pkgs=()
    local -a unmapped_tools=()
    local -a mapped_tools=()
    local -a overridden_tools=()
    
    for tool in "${TOOLS_TO_INSTALL[@]}"; do
        local m_override
        m_override=$(get_tool_method_override "${tool}")
        if [[ -n "${m_override}" && "${m_override,,}" != "native" && "${m_override,,}" != "${PACKAGE_MANAGER}" ]]; then
            overridden_tools+=("${tool}")
            continue
        fi
        local pkg
        pkg=$(get_distro_pkg_name "${tool}")
        if [[ -n "${pkg}" ]]; then
            mapped_tools+=("${tool}")
            if [[ -z "${seen_pkgs["${pkg}"]:-}" ]]; then
                seen_pkgs["${pkg}"]="1"
                batch_pkgs+=("${pkg}")
            fi
        else
            unmapped_tools+=("${tool}")
        fi
    done
    
    for tool in "${unmapped_tools[@]}"; do
        warn "No package mapping for ${tool} on ${DISTRO_FAMILY}"
        INSTALL_RESULTS+=("SKIPPED:${tool} (no mapping)")
    done
    
    if [[ ${#mapped_tools[@]} -eq 0 && ${#overridden_tools[@]} -eq 0 ]]; then
        info "No packages available to install for ${DISTRO_FAMILY}."
        return 0
    fi
    
    local batch_supported=true
    local -a batch_cmd=()
    case "${PACKAGE_MANAGER}" in
        pacman)
            batch_cmd=(pacman -S --noconfirm --needed "${batch_pkgs[@]}")
            ;;
        apt)
            batch_cmd=(apt install -y "${batch_pkgs[@]}")
            ;;
        dnf)
            batch_cmd=(dnf install -y "${batch_pkgs[@]}")
            ;;
        zypper)
            batch_cmd=(zypper install -y "${batch_pkgs[@]}")
            ;;
        apk)
            batch_cmd=(apk add "${batch_pkgs[@]}")
            ;;
        xbps)
            batch_cmd=(xbps-install -y "${batch_pkgs[@]}")
            ;;
        emerge)
            batch_cmd=(emerge "${batch_pkgs[@]}")
            ;;
        *)
            batch_supported=false
            ;;
    esac
    
    if [[ "${batch_supported}" == "true" && ${#batch_pkgs[@]} -gt 0 ]]; then
        info "Attempting batch installation of ${#batch_pkgs[@]} packages..."
        local batch_res=0
        run_cmd "${batch_cmd[@]}" || batch_res=$?
        if [[ ${batch_res} -eq 0 ]]; then
            for tool in "${mapped_tools[@]}"; do
                local pkg
                pkg=$(get_distro_pkg_name "${tool}")
                success "Installed: ${tool} (${pkg})"
                INSTALL_RESULTS+=("SUCCESS:${tool}")
            done
            for tool in "${overridden_tools[@]}"; do
                install_package "${tool}" || true
            done
            return 0
        fi
        warn "Batch installation failed (exit code ${batch_res}). Falling back to individual package installation..."
    fi
    
    local current=0
    local -a all_to_install=("${mapped_tools[@]}" "${overridden_tools[@]}")
    for tool in "${all_to_install[@]}"; do
        current=$((current + 1))
        info "[${current}/${#all_to_install[@]}] Installing ${tool}..."
        install_package "${tool}" || true
    done
}

declare -gA INSTALLED_PIPX_PACKAGES=([_init]="")
declare -gA INSTALLED_PIP_PACKAGES=([_init]="")
declare -g PIP_CACHE_INITIALIZED=false

init_installed_pip_cache() {
    [[ "${PIP_CACHE_INITIALIZED}" == "true" ]] && return 0
    INSTALLED_PIPX_PACKAGES=()
    INSTALLED_PIP_PACKAGES=()
    
    if command -v pipx &>/dev/null; then
        local line pkg ver
        while read -r line; do
            [[ -z "${line}" ]] && continue
            pkg="${line%% *}"
            ver="${line#* }"
            [[ -n "${pkg}" ]] && INSTALLED_PIPX_PACKAGES["${pkg,,}"]="${ver}"
        done < <(pipx list --short 2>/dev/null || true)
    elif command -v pip3 &>/dev/null; then
        local line pkg ver
        while IFS='==' read -r pkg ver; do
            [[ -z "${pkg}" ]] && continue
            INSTALLED_PIP_PACKAGES["${pkg,,}"]="${ver}"
        done < <(pip3 list --format=freeze 2>/dev/null || true)
    fi
    
    PIP_CACHE_INITIALIZED=true
}

get_installed_tool_info() {
    local tool="$1"
    local pkg_name
    pkg_name=$(get_distro_pkg_name "${tool}")
    local pip_pkg
    pip_pkg=$(get_tool_pip_pkg "${tool}")
    
    local installed=false
    local method="none"
    local version="unknown"
    
    # 1. Native package check
    if [[ -n "${pkg_name}" ]] && is_pkg_installed "${pkg_name}"; then
        installed=true
        method="${PACKAGE_MANAGER}"
        
        # Check if AUR package on Arch
        if [[ "${PACKAGE_MANAGER}" == "pacman" ]]; then
            if pacman -Qm "${pkg_name}" &>/dev/null; then
                method="aur"
            fi
            version=$(pacman -Q "${pkg_name}" 2>/dev/null | awk '{print $2}' || true)
        elif [[ "${PACKAGE_MANAGER}" == "apt" ]]; then
            version=$(dpkg-query -W -f='${Version}' "${pkg_name}" 2>/dev/null || true)
        elif [[ "${PACKAGE_MANAGER}" == "dnf" ]]; then
            version=$(rpm -q --qf '%{VERSION}-%{RELEASE}' "${pkg_name}" 2>/dev/null || true)
        fi
        [[ -z "${version}" ]] && version="installed"
    fi
    
    # 2. pip / pipx check (cached)
    if [[ "${installed}" != "true" && -n "${pip_pkg}" ]]; then
        init_installed_pip_cache
        local p_lower="${pip_pkg,,}"
        if [[ -n "${INSTALLED_PIPX_PACKAGES["${p_lower}"]:-}" ]]; then
            installed=true
            method="pipx"
            version="${INSTALLED_PIPX_PACKAGES["${p_lower}"]}"
        elif [[ -n "${INSTALLED_PIP_PACKAGES["${p_lower}"]:-}" ]]; then
            installed=true
            method="pip"
            version="${INSTALLED_PIP_PACKAGES["${p_lower}"]}"
        fi
    fi
    
    # 3. Source build check (/usr/local/bin or /opt)
    if [[ "${installed}" != "true" ]]; then
        if [[ -f "/usr/local/bin/${tool}" || -L "/usr/local/bin/${tool}" || -d "/opt/${tool}" ]]; then
            installed=true
            method="source"
            if command -v "${tool}" &>/dev/null; then
                version=$("${tool}" --version 2>/dev/null | head -n 1 | grep -oE '[0-9]+(\.[0-9]+)+' | head -n 1 || true)
            fi
            [[ -z "${version}" ]] && version="source"
        fi
    fi
    
    echo "${installed}|${method}|${version}"
}

list_installed_tools() {
    info "Scanning installed Kali tools across all tiers..."
    local -a all_tools=()
    mapfile -t all_tools < <(list_all_tools)
    
    local -a installed_entries=()
    local count_native=0 count_aur=0 count_pip=0 count_source=0
    
    for tool in "${all_tools[@]}"; do
        local info_str
        info_str=$(get_installed_tool_info "${tool}")
        local is_inst method ver
        IFS='|' read -r is_inst method ver <<< "${info_str}"
        if [[ "${is_inst}" == "true" ]]; then
            local cat
            cat=$(get_tool_category "${tool}")
            installed_entries+=("${tool}|${cat}|${method}|${ver}")
            case "${method}" in
                aur)    count_aur=$((count_aur + 1)) ;;
                pip*)   count_pip=$((count_pip + 1)) ;;
                source) count_source=$((count_source + 1)) ;;
                *)      count_native=$((count_native + 1)) ;;
            esac
        fi
    done
    
    echo
    info "=== Installed Kali Tools Dashboard ==="
    info "Distribution: ${DISTRO:-unknown} (${DISTRO_FAMILY:-unknown})"
    echo
    printf "  %-22s %-14s %-12s %-18s\n" "TOOL" "CATEGORY" "METHOD" "VERSION"
    printf "  %-22s %-14s %-12s %-18s\n" "----------------------" "--------------" "------------" "------------------"
    
    if [[ ${#installed_entries[@]} -eq 0 ]]; then
        info "  (No Kali tools currently installed)"
    else
        for entry in "${installed_entries[@]}"; do
            local t_name t_cat t_method t_ver
            IFS='|' read -r t_name t_cat t_method t_ver <<< "${entry}"
            printf "  %-22s %-14s %-12s %-18s\n" "${t_name}" "${t_cat}" "${t_method}" "${t_ver}"
        done
    fi
    echo
    local total_all=${#all_tools[@]}
    local total_inst=${#installed_entries[@]}
    local pct=0
    [[ ${total_all} -gt 0 ]] && pct=$((total_inst * 100 / total_all))
    info "Total installed: ${total_inst} / ${total_all} (${pct}%)"
    info "Breakdown: native: ${count_native} | aur: ${count_aur} | pip/pipx: ${count_pip} | source: ${count_source}"
    
    if [[ -n "${EXPORT_REPORT_FILE:-}" ]]; then
        declare -ga INSTALL_RESULTS=()
        for entry in "${installed_entries[@]}"; do
            local t_name t_cat t_method t_ver
            IFS='|' read -r t_name t_cat t_method t_ver <<< "${entry}"
            INSTALL_RESULTS+=("INSTALLED:${t_name} (${t_method} ${t_ver})")
        done
        export_report
    fi
}

run_update() {
    info "=== Kali Tools Auto-Update Engine ==="
    info "Distribution: ${DISTRO:-unknown} (${DISTRO_FAMILY:-unknown})"
    info "Package Manager: ${PACKAGE_MANAGER:-unknown}"
    echo
    
    local -a all_tools=()
    mapfile -t all_tools < <(list_all_tools)
    
    local -a native_pkgs=()
    local -a aur_pkgs=()
    local -a pip_pkgs=()
    local -a source_tools=()
    local -a updated_tools=()
    
    for tool in "${all_tools[@]}"; do
        local info_str
        info_str=$(get_installed_tool_info "${tool}")
        local is_inst method ver
        IFS='|' read -r is_inst method ver <<< "${info_str}"
        if [[ "${is_inst}" == "true" ]]; then
            case "${method}" in
                aur)
                    local pkg
                    pkg=$(get_distro_pkg_name "${tool}")
                    [[ -n "${pkg}" ]] && aur_pkgs+=("${pkg}")
                    updated_tools+=("${tool}")
                    ;;
                pip|pipx)
                    local p_pkg
                    p_pkg=$(get_tool_pip_pkg "${tool}")
                    [[ -z "${p_pkg}" ]] && p_pkg="${tool}"
                    pip_pkgs+=("${p_pkg}")
                    updated_tools+=("${tool}")
                    ;;
                source)
                    source_tools+=("${tool}")
                    updated_tools+=("${tool}")
                    ;;
                *)
                    local pkg
                    pkg=$(get_distro_pkg_name "${tool}")
                    [[ -n "${pkg}" ]] && native_pkgs+=("${pkg}")
                    updated_tools+=("${tool}")
                    ;;
            esac
        fi
    done
    
    if [[ ${#updated_tools[@]} -eq 0 ]]; then
        info "No installed Kali tools detected to update."
        return 0
    fi
    
    info "Found ${#updated_tools[@]} installed Kali tools to update."
    
    # Check root if not dry-run and updating native packages
    if [[ "${DRY_RUN}" != "true" && ${#native_pkgs[@]} -gt 0 ]]; then
        check_root
    fi
    
    # 1. Update native packages
    if [[ ${#native_pkgs[@]} -gt 0 ]]; then
        info "Updating ${#native_pkgs[@]} native packages..."
        local -a update_cmd=()
        case "${PACKAGE_MANAGER}" in
            pacman)   update_cmd=(pacman -S --noconfirm --needed "${native_pkgs[@]}") ;;
            apt)      update_cmd=(apt install --only-upgrade -y "${native_pkgs[@]}") ;;
            dnf)      update_cmd=(dnf upgrade -y "${native_pkgs[@]}") ;;
            zypper)   update_cmd=(zypper update -y "${native_pkgs[@]}") ;;
            apk)      update_cmd=(apk upgrade "${native_pkgs[@]}") ;;
            xbps)     update_cmd=(xbps-install -u "${native_pkgs[@]}") ;;
            emerge)   update_cmd=(emerge -u "${native_pkgs[@]}") ;;
            slackpkg) update_cmd=(slackpkg upgrade "${native_pkgs[@]}") ;;
            *)        update_cmd=() ;;
        esac
        
        if [[ ${#update_cmd[@]} -gt 0 ]]; then
            local u_res=0
            run_cmd "${update_cmd[@]}" || u_res=$?
            if [[ ${u_res} -eq 0 ]]; then
                for p in "${native_pkgs[@]}"; do
                    INSTALL_RESULTS+=("SUCCESS:${p} (native update)")
                done
            else
                warn "Native package update failed (exit code ${u_res})"
                for p in "${native_pkgs[@]}"; do
                    INSTALL_RESULTS+=("FAILED:${p} (native update)")
                done
            fi
        fi
    fi
    
    # 2. Update AUR packages
    if [[ ${#aur_pkgs[@]} -gt 0 && "${PACKAGE_MANAGER}" == "pacman" ]]; then
        local aur_helper
        aur_helper=$(get_aur_helper)
        if [[ -n "${aur_helper}" ]]; then
            info "Updating ${#aur_pkgs[@]} AUR packages via ${aur_helper}..."
            local aur_res=0
            run_aur_cmd "${aur_helper}" -S --noconfirm --needed "${aur_pkgs[@]}" || aur_res=$?
            if [[ ${aur_res} -eq 0 ]]; then
                for p in "${aur_pkgs[@]}"; do
                    INSTALL_RESULTS+=("SUCCESS:${p} (aur update)")
                done
            else
                warn "AUR update failed (exit code ${aur_res})"
            fi
        fi
    fi
    
    # 3. Update pip/pipx packages
    if [[ ${#pip_pkgs[@]} -gt 0 ]]; then
        info "Updating ${#pip_pkgs[@]} pip/pipx packages..."
        for p_pkg in "${pip_pkgs[@]}"; do
            if [[ "${DRY_RUN}" == "true" ]]; then
                if command -v pipx &>/dev/null; then
                    info "[DRY RUN] pipx upgrade ${p_pkg}"
                else
                    info "[DRY RUN] pip3 install --upgrade ${p_pkg}"
                fi
                INSTALL_RESULTS+=("SUCCESS:${p_pkg} (pip update)")
            else
                local p_res=0
                if command -v pipx &>/dev/null && pipx list 2>/dev/null | grep -q "package ${p_pkg}"; then
                    pipx upgrade "${p_pkg}" 2>&1 | tee -a "${LOG_FILE}" || p_res=$?
                elif command -v pip3 &>/dev/null; then
                    local pip_flags=()
                    if pip3 install --help 2>/dev/null | grep -q -- '--break-system-packages'; then
                        pip_flags=(--break-system-packages)
                    else
                        pip_flags=(--user)
                    fi
                    pip3 install --upgrade "${pip_flags[@]}" "${p_pkg}" 2>&1 | tee -a "${LOG_FILE}" || p_res=$?
                fi
                if [[ ${p_res} -eq 0 ]]; then
                    INSTALL_RESULTS+=("SUCCESS:${p_pkg} (pip update)")
                else
                    INSTALL_RESULTS+=("FAILED:${p_pkg} (pip update)")
                fi
            fi
        done
    fi
    
    # 4. Update Git source tools
    if [[ ${#source_tools[@]} -gt 0 ]]; then
        info "Updating ${#source_tools[@]} source-installed tools..."
        for s_tool in "${source_tools[@]}"; do
            if [[ -d "/opt/${s_tool}/.git" ]]; then
                if [[ "${DRY_RUN}" == "true" ]]; then
                    info "[DRY RUN] git -C /opt/${s_tool} pull"
                    INSTALL_RESULTS+=("SUCCESS:${s_tool} (source update)")
                else
                    info "Pulling latest git changes for ${s_tool}..."
                    if git -C "/opt/${s_tool}" pull 2>&1 | tee -a "${LOG_FILE}"; then
                        INSTALL_RESULTS+=("SUCCESS:${s_tool} (source update)")
                    else
                        INSTALL_RESULTS+=("FAILED:${s_tool} (source update)")
                    fi
                fi
            fi
        done
    fi
    
    print_summary
}

run_diff() {
    info "=== Kali Tools Scope Diff Matrix ==="
    info "Distribution: ${DISTRO:-unknown} (${DISTRO_FAMILY:-unknown})"
    
    # 1. Resolve scope
    local -a scope_tools=()
    local scope_name="All Tools"
    if [[ -n "${SELECTED_PRESET:-}" ]]; then
        scope_name="Preset '${SELECTED_PRESET}'"
        read -ra scope_tools <<< "$(get_tools_in_preset "${SELECTED_PRESET}")"
    elif [[ ${#SELECTED_CATEGORIES[@]} -gt 0 ]]; then
        scope_name="Categories: ${SELECTED_CATEGORIES[*]}"
        for c in "${SELECTED_CATEGORIES[@]}"; do
            local -a c_tools=()
            read -ra c_tools <<< "$(get_tools_in_category "${c}")"
            scope_tools+=("${c_tools[@]}")
        done
    elif [[ ${#SELECTED_TOOLS[@]} -gt 0 ]]; then
        scope_name="Specific Tools (${#SELECTED_TOOLS[@]})"
        scope_tools=("${SELECTED_TOOLS[@]}")
    else
        mapfile -t scope_tools < <(list_all_tools)
    fi
    
    info "Target Scope: ${scope_name} (${#scope_tools[@]} tools)"
    echo
    
    printf "  %-8s %-22s %-14s %-28s\n" "STATUS" "TOOL" "CATEGORY" "METHOD / REPO DETAILS"
    printf "  %-8s %-22s %-14s %-28s\n" "------" "----------------------" "--------------" "----------------------------"
    
    local count_installed=0
    local count_missing=0
    local -a diff_report_entries=()
    
    for tool in "${scope_tools[@]}"; do
        local cat
        cat=$(get_tool_category "${tool}")
        local info_str
        info_str=$(get_installed_tool_info "${tool}")
        local is_inst method ver
        IFS='|' read -r is_inst method ver <<< "${info_str}"
        
        local status_tag=""
        local details=""
        if [[ "${is_inst}" == "true" ]]; then
            status_tag="[ + ]"
            details="${method} (${ver})"
            count_installed=$((count_installed + 1))
            diff_report_entries+=("INSTALLED|${tool}|${cat}|${details}")
        else
            status_tag="[ - ]"
            local pkg
            pkg=$(get_distro_pkg_name "${tool}")
            local pip_p
            pip_p=$(get_tool_pip_pkg "${tool}")
            local ba_p
            ba_p=$(get_tool_blackarch_pkg "${tool}")
            if [[ -n "${pkg}" ]]; then
                details="not installed (${PACKAGE_MANAGER}: ${pkg})"
            elif [[ -n "${pip_p}" ]]; then
                details="not installed (pypi: ${pip_p})"
            elif [[ -n "${ba_p}" ]]; then
                details="not installed (blackarch: ${ba_p})"
            else
                details="not installed (unmapped)"
            fi
            count_missing=$((count_missing + 1))
            diff_report_entries+=("MISSING|${tool}|${cat}|${details}")
        fi
        
        printf "  %-8s %-22s %-14s %-28s\n" "${status_tag}" "${tool}" "${cat}" "${details}"
    done
    
    local total=${#scope_tools[@]}
    local inst_pct=0
    local miss_pct=0
    if [[ ${total} -gt 0 ]]; then
        inst_pct=$((count_installed * 100 / total))
        miss_pct=$((count_missing * 100 / total))
    fi
    
    echo
    info "=== Diff Summary ==="
    success "Installed: ${count_installed} / ${total} (${inst_pct}%)"
    if [[ ${count_missing} -gt 0 ]]; then
        error "Missing:   ${count_missing} / ${total} (${miss_pct}%)"
    fi
    
    if [[ -n "${EXPORT_REPORT_FILE:-}" ]]; then
        declare -ga INSTALL_RESULTS=()
        for d in "${diff_report_entries[@]}"; do
            IFS='|' read -r st t_name t_cat t_det <<< "${d}"
            INSTALL_RESULTS+=("${st}:${t_name} (${t_det})")
        done
        export_report
    fi
}

uninstall_single_package() {
    local tool="$1"
    local pkg="$2"
    
    info "Removing ${tool} (${pkg})..."
    local res=0
    case "${PACKAGE_MANAGER}" in
        pacman) run_cmd pacman -R --noconfirm "${pkg}" || res=$? ;;
        apt) run_cmd apt purge -y "${pkg}" || res=$? ;;
        dnf) run_cmd dnf remove -y "${pkg}" || res=$? ;;
        zypper) run_cmd zypper remove -y "${pkg}" || res=$? ;;
        apk) run_cmd apk del "${pkg}" || res=$? ;;
        xbps) run_cmd xbps-remove -y "${pkg}" || res=$? ;;
        emerge) run_cmd emerge -C "${pkg}" || res=$? ;;
        slackpkg) run_cmd slackpkg remove "${pkg}" || res=$? ;;
        *) res=1 ;;
    esac
    
    if [[ ${res} -eq 0 ]]; then
        success "Uninstalled: ${tool} (${pkg})"
        INSTALL_RESULTS+=("REMOVED:${tool}")
    else
        error "Failed to uninstall: ${tool} (${pkg})"
        INSTALL_RESULTS+=("FAILED:${tool}")
    fi
    return ${res}
}

remove_source_tool() {
    local tool="$1"
    info "Removing source files for ${tool}..."
    
    # Determine pip_pkg mapping for cleanup
    local pip_pkg
    pip_pkg=$(get_tool_pip_pkg "${tool}")
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        [[ -f "/usr/local/bin/${tool}" || -L "/usr/local/bin/${tool}" ]] && info "[DRY RUN] rm -f /usr/local/bin/${tool}"
        [[ -d "/opt/${tool}" ]] && info "[DRY RUN] rm -rf /opt/${tool}"
        [[ -n "${pip_pkg}" ]] && info "[DRY RUN] pipx uninstall ${pip_pkg} (or pip3 uninstall ${pip_pkg})"
        INSTALL_RESULTS+=("REMOVED:${tool} (source)")
        return 0
    fi
    
    local removed=false
    if [[ -f "/usr/local/bin/${tool}" || -L "/usr/local/bin/${tool}" ]]; then
        rm -f "/usr/local/bin/${tool}" && removed=true
    fi
    if [[ -d "/opt/${tool}" ]]; then
        rm -rf "/opt/${tool}" && removed=true
    fi
    
    # Uninstall via pipx if available, otherwise pip3
    if [[ -n "${pip_pkg}" ]]; then
        if command -v pipx &>/dev/null; then
            pipx uninstall "${pip_pkg}" 2>/dev/null && removed=true || true
        elif command -v pip3 &>/dev/null; then
            pip3 uninstall -y "${pip_pkg}" 2>/dev/null && removed=true || true
        fi
    elif command -v pip3 &>/dev/null; then
        # Legacy: try by tool name
        pip3 uninstall -y "${tool}" 2>/dev/null || true
    fi
    
    if [[ "${removed}" == "true" ]]; then
        success "Removed: ${tool}"
        INSTALL_RESULTS+=("REMOVED:${tool} (source)")
    fi
}


run_uninstallation() {
    info "Starting uninstallation of ${#TOOLS_TO_INSTALL[@]} tools..."
    
    local -a batch_pkgs=()
    local -A seen_pkgs=()
    local -a source_tools=()
    local -a mapped_installed_tools=()
    
    for tool in "${TOOLS_TO_INSTALL[@]}"; do
        local pkg
        pkg=$(get_distro_pkg_name "${tool}")
        local is_installed=false
        
        if [[ -n "${pkg}" ]]; then
            if is_pkg_installed "${pkg}" || [[ "${DRY_RUN}" == "true" ]]; then
                is_installed=true
                mapped_installed_tools+=("${tool}")
                if [[ -z "${seen_pkgs["${pkg}"]:-}" ]]; then
                    seen_pkgs["${pkg}"]="1"
                    batch_pkgs+=("${pkg}")
                fi
            fi
        fi
        
        if [[ -f "/usr/local/bin/${tool}" || -L "/usr/local/bin/${tool}" || -d "/opt/${tool}" ]]; then
            source_tools+=("${tool}")
            is_installed=true
        fi
        
        if [[ "${is_installed}" != "true" ]]; then
            INSTALL_RESULTS+=("NOT_INSTALLED:${tool}")
        fi
    done
    
    # 1. Native package removal
    if [[ ${#batch_pkgs[@]} -gt 0 ]]; then
        info "Attempting removal of ${#batch_pkgs[@]} native packages..."
        local batch_supported=true
        local -a batch_cmd=()
        case "${PACKAGE_MANAGER}" in
            pacman) batch_cmd=(pacman -R --noconfirm "${batch_pkgs[@]}") ;;
            apt) batch_cmd=(apt purge -y "${batch_pkgs[@]}") ;;
            dnf) batch_cmd=(dnf remove -y "${batch_pkgs[@]}") ;;
            zypper) batch_cmd=(zypper remove -y "${batch_pkgs[@]}") ;;
            apk) batch_cmd=(apk del "${batch_pkgs[@]}") ;;
            xbps) batch_cmd=(xbps-remove -y "${batch_pkgs[@]}") ;;
            emerge) batch_cmd=(emerge -C "${batch_pkgs[@]}") ;;
            *) batch_supported=false ;;
        esac
        
        if [[ "${batch_supported}" == "true" ]]; then
            local batch_res=0
            run_cmd "${batch_cmd[@]}" || batch_res=$?
            if [[ ${batch_res} -eq 0 ]]; then
                for tool in "${mapped_installed_tools[@]}"; do
                    local pkg
                    pkg=$(get_distro_pkg_name "${tool}")
                    success "Uninstalled: ${tool} (${pkg})"
                    INSTALL_RESULTS+=("REMOVED:${tool}")
                done
            else
                warn "Batch removal failed (exit code ${batch_res}). Falling back to individual package removal..."
                for tool in "${mapped_installed_tools[@]}"; do
                    local pkg
                    pkg=$(get_distro_pkg_name "${tool}")
                    uninstall_single_package "${tool}" "${pkg}" || true
                done
            fi
        else
            for tool in "${mapped_installed_tools[@]}"; do
                local pkg
                pkg=$(get_distro_pkg_name "${tool}")
                uninstall_single_package "${tool}" "${pkg}" || true
            done
        fi
    fi
    
    # 2. Source-installed cleanup
    if [[ ${#source_tools[@]} -gt 0 ]]; then
        info "Cleaning up ${#source_tools[@]} source-installed tools..."
        for tool in "${source_tools[@]}"; do
            remove_source_tool "${tool}"
        done
    fi
}

print_uninstall_summary() {
    echo
    info "=== Uninstallation Summary ==="
    
    local removed=0
    local not_installed=0
    local failed=0
    
    for result in "${INSTALL_RESULTS[@]}"; do
        local status="${result%%:*}"
        
        case "${status}" in
            REMOVED)
                ((removed+=1))
                ;;
            NOT_INSTALLED)
                ((not_installed+=1))
                ;;
            FAILED)
                ((failed+=1))
                ;;
        esac
    done
    
    info "Total tools evaluated: ${#TOOLS_TO_INSTALL[@]}"
    if [[ ${removed} -gt 0 ]]; then
        success "Successfully uninstalled: ${removed}"
    fi
    if [[ ${not_installed} -gt 0 ]]; then
        info "Not installed (skipped): ${not_installed}"
    fi
    if [[ ${failed} -gt 0 ]]; then
        error "Failed to uninstall: ${failed}"
    fi
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        echo
        info "Dry run complete. No packages or files were removed."
    fi
    type export_report &>/dev/null && export_report || true
}

check_package_available() {
    local pkg_name="$1"
    local tool="${2:-}"   # optional: used to look up pip_pkg and blackarch_pkg
    
    case "${PACKAGE_MANAGER}" in
        pacman)
            if pacman -Si "${pkg_name}" &>/dev/null; then
                echo "OFFICIAL"; return 0
            fi
            local aur_helper
            aur_helper=$(get_aur_helper || true)
            if [[ -n "${aur_helper}" ]] && "${aur_helper}" -Si "${pkg_name}" &>/dev/null; then
                echo "AUR"; return 0
            fi
            ;;
        apt)
            if apt-cache show "${pkg_name}" &>/dev/null; then
                echo "OFFICIAL"; return 0
            fi
            ;;
        dnf)
            if { rpm -q "${pkg_name}" &>/dev/null || dnf info "${pkg_name}" &>/dev/null || dnf repoquery "${pkg_name}" &>/dev/null; }; then
                echo "OFFICIAL"; return 0
            fi
            ;;
        zypper)
            if zypper info "${pkg_name}" &>/dev/null; then
                echo "OFFICIAL"; return 0
            fi
            ;;
        slackpkg)
            if slackpkg search "${pkg_name}" 2>/dev/null | grep -q "${pkg_name}"; then
                echo "OFFICIAL"; return 0
            fi
            ;;
        emerge)
            if emerge --search "%@^${pkg_name}$" &>/dev/null; then
                echo "OFFICIAL"; return 0
            fi
            ;;
        apk)
            if apk info "${pkg_name}" &>/dev/null; then
                echo "OFFICIAL"; return 0
            fi
            ;;
        xbps)
            if xbps-query -R "${pkg_name}" &>/dev/null; then
                echo "OFFICIAL"; return 0
            fi
            ;;
    esac
    
    # pipx/pip tier — if tool has a pip_pkg mapping, it's installable via PyPI
    if [[ -n "${tool}" ]]; then
        local pip_pkg
        pip_pkg=$(get_tool_pip_pkg "${tool}")
        if [[ -n "${pip_pkg}" ]]; then
            echo "PIPX"; return 0
        fi
        
        # BlackArch tier — Arch only, if tool has a blackarch_pkg mapping
        if [[ "${PACKAGE_MANAGER}" == "pacman" ]]; then
            local ba_pkg
            ba_pkg=$(get_tool_blackarch_pkg "${tool}")
            if [[ -n "${ba_pkg}" ]]; then
                echo "BLACKARCH"; return 0
            fi
        fi
    fi
    
    echo "MISSING"; return 1
}


check_build_from_source() {
    local tool="$1"
    local pkg_name="${2:-}"
    local buildable=false
    local source_url=""
    local build_method=""
    
    case "${tool}" in
        # Tools available via Go
        gobuster)
            buildable=true; build_method="go"; source_url="https://github.com/OJ/gobuster" ;;
        gowitness)
            buildable=true; build_method="go"; source_url="https://github.com/sensepost/gowitness" ;;
        feroxbuster)
            buildable=true; build_method="go"; source_url="https://github.com/epi052/feroxbuster" ;;
        bettercap)
            buildable=true; build_method="go"; source_url="https://github.com/bettercap/bettercap" ;;
        sliver)
            buildable=true; build_method="go"; source_url="https://github.com/BishopFox/sliver" ;;
            
        # Python tools
        sqlmap)
            buildable=true; build_method="pip"; source_url="https://github.com/sqlmapproject/sqlmap" ;;
        wfuzz)
            buildable=true; build_method="pip"; source_url="https://github.com/xmendez/wfuzz" ;;
        recon-ng)
            buildable=true; build_method="pip"; source_url="https://github.com/lanmaster53/recon-ng" ;;
        dnsrecon)
            buildable=true; build_method="pip"; source_url="https://github.com/darkoperator/dnsrecon" ;;
        theharvester)
            buildable=true; build_method="pip"; source_url="https://github.com/laramies/theHarvester" ;;
        volatility)
            buildable=true; build_method="pip"; source_url="https://github.com/volatilityfoundation/volatility" ;;
        volatility3)
            buildable=true; build_method="pip"; source_url="https://github.com/volatilityfoundation/volatility3" ;;
        binwalk)
            buildable=true; build_method="pip"; source_url="https://github.com/ReFirmLabs/binwalk" ;;
        mitmproxy)
            buildable=true; build_method="pip"; source_url="https://github.com/mitmproxy/mitmproxy" ;;
        cupp)
            buildable=true; build_method="pip"; source_url="https://github.com/Mebus/cupp" ;;
        pwntools)
            buildable=true; build_method="pip"; source_url="https://github.com/Gallopsled/pwntools" ;;
        ropper)
            buildable=true; build_method="pip"; source_url="https://github.com/sashs/Ropper" ;;
        ropgadget)
            buildable=true; build_method="pip"; source_url="https://github.com/JonathanSalwan/ROPgadget" ;;
        gef)
            buildable=true; build_method="pip"; source_url="https://github.com/hugsy/gef" ;;
        pwndbg)
            buildable=true; build_method="pip"; source_url="https://github.com/pwndbg/pwndbg" ;;
        setoolkit)
            buildable=true; build_method="pip"; source_url="https://github.com/trustedsec/social-engineer-toolkit" ;;
        wifite)
            buildable=true; build_method="pip"; source_url="https://github.com/derv82/wifite2" ;;
            
        # C / Make / CMake tools
        masscan)
            buildable=true; build_method="make"; source_url="https://github.com/robertdavidgraham/masscan" ;;
        hashcat)
            buildable=true; build_method="make"; source_url="https://github.com/hashcat/hashcat" ;;
        john)
            buildable=true; build_method="make"; source_url="https://github.com/openwall/john" ;;
        hydra)
            buildable=true; build_method="make"; source_url="https://github.com/vanhauser-thc/thc-hydra" ;;
        medusa)
            buildable=true; build_method="make"; source_url="https://github.com/jmk-foofus/medusa" ;;
        ncrack)
            buildable=true; build_method="make"; source_url="https://github.com/nmap/ncrack" ;;
        crunch)
            buildable=true; build_method="make"; source_url="https://github.com/crunchsec/crunch" ;;
        aircrack-ng)
            buildable=true; build_method="make"; source_url="https://github.com/aircrack-ng/aircrack-ng" ;;
        dirb)
            buildable=true; build_method="make"; source_url="https://github.com/v00d00sec/dirb" ;;
        sleuthkit)
            buildable=true; build_method="make"; source_url="https://github.com/sleuthkit/sleuthkit" ;;
        radare2)
            buildable=true; build_method="make"; source_url="https://github.com/radareorg/radare2" ;;
        checksec)
            buildable=true; build_method="make"; source_url="https://github.com/slimm609/checksec.sh" ;;
        bulk-extractor)
            buildable=true; build_method="make"; source_url="https://github.com/simsong/bulk_extractor" ;;
        proxychains)
            buildable=true; build_method="make"; source_url="https://github.com/rofl0r/proxychains-ng" ;;
        stunnel)
            buildable=true; build_method="make"; source_url="https://github.com/mtrojnar/stunnel" ;;
        socat)
            buildable=true; build_method="make"; source_url="https://repo.or.cz/socat.git" ;;
            
        # Perl / Ruby / Other tools
        nikto)
            buildable=true; build_method="git"; source_url="https://github.com/sullo/nikto" ;;
        wpscan)
            buildable=true; build_method="gem"; source_url="https://github.com/wpscanteam/wpscan" ;;
        whatweb)
            buildable=true; build_method="git"; source_url="https://github.com/urbanadventurer/WhatWeb" ;;
        beef)
            buildable=true; build_method="git"; source_url="https://github.com/beefproject/beef" ;;
        cewl)
            buildable=true; build_method="gem"; source_url="https://github.com/digininja/CeWL" ;;
        autopsy)
            buildable=true; build_method="git"; source_url="https://github.com/sleuthkit/autopsy" ;;
        rizin)
            buildable=true; build_method="cmake"; source_url="https://github.com/rizinorg/rizin" ;;
            
        *)
            buildable=false
            build_method="unknown"
            ;;
    esac
    
    if [[ "${buildable}" == "true" ]]; then
        echo "BUILDABLE:${build_method}:${source_url}"
        return 0
    else
        echo "NOT_BUILDABLE"
        return 1
    fi
}

ensure_build_prerequisites() {
    local method="$1"
    local tool="${2:-}"
    
    local prereq_tokens
    prereq_tokens=$(get_build_prerequisites "${method}")
    
    local tool_deps
    tool_deps=$(get_tool_deps "${tool}")
    if [[ -n "${tool_deps}" ]]; then
        prereq_tokens+=" ${tool_deps//,/ }"
    fi
    
    local -a missing_pkgs=()
    local -A seen_pkgs=()
    
    for token in ${prereq_tokens}; do
        token="${token#"${token%%[![:space:]]*}"}"
        token="${token%"${token##*[![:space:]]}"}"
        [[ -z "${token}" ]] && continue
        
        local need_install=false
        case "${token}" in
            go|golang) command -v go &>/dev/null || need_install=true ;;
            pip|pip3|python3-pip) command -v pip3 &>/dev/null || command -v pip &>/dev/null || need_install=true ;;
            python|python3) command -v python3 &>/dev/null || command -v python &>/dev/null || need_install=true ;;
            git) command -v git &>/dev/null || need_install=true ;;
            make) command -v make &>/dev/null || need_install=true ;;
            cmake) command -v cmake &>/dev/null || need_install=true ;;
            gcc) command -v gcc &>/dev/null || need_install=true ;;
            ruby|gem) command -v ruby &>/dev/null || command -v gem &>/dev/null || need_install=true ;;
            *)
                local pkg
                pkg=$(resolve_dep_pkg "${token}" "${DISTRO_FAMILY}")
                if [[ -n "${pkg}" ]] && ! is_pkg_installed "${pkg}"; then
                    need_install=true
                fi
                ;;
        esac
        
        if [[ "${need_install}" == "true" ]]; then
            local resolved_pkg
            resolved_pkg=$(resolve_dep_pkg "${token}" "${DISTRO_FAMILY}")
            if [[ -n "${resolved_pkg}" ]]; then
                local -a split_pkgs=()
                IFS=',' read -ra split_pkgs <<< "${resolved_pkg}"
                for p in "${split_pkgs[@]}"; do
                    p="${p#"${p%%[![:space:]]*}"}"
                    p="${p%"${p##*[![:space:]]}"}"
                    if [[ -n "${p}" && -z "${seen_pkgs["${p}"]:-}" ]]; then
                        seen_pkgs["${p}"]="1"
                        if ! is_pkg_installed "${p}"; then
                            missing_pkgs+=("${p}")
                        fi
                    fi
                done
            fi
        fi
    done
    
    if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
        info "Build prerequisites needed for ${tool} (${method}): ${missing_pkgs[*]}"
        if [[ "${DRY_RUN}" == "true" ]]; then
            info "[DRY RUN] Would install build prerequisites: ${missing_pkgs[*]}"
            return 0
        fi
        
        case "${PACKAGE_MANAGER}" in
            pacman) run_cmd pacman -S --noconfirm --needed "${missing_pkgs[@]}" ;;
            apt) run_cmd apt install -y "${missing_pkgs[@]}" ;;
            dnf) run_cmd dnf install -y "${missing_pkgs[@]}" ;;
            zypper) run_cmd zypper install -y "${missing_pkgs[@]}" ;;
            apk) run_cmd apk add "${missing_pkgs[@]}" ;;
            xbps) run_cmd xbps-install -y "${missing_pkgs[@]}" ;;
            emerge) run_cmd emerge "${missing_pkgs[@]}" ;;
            slackpkg)
                for p in "${missing_pkgs[@]}"; do
                    run_cmd slackpkg install "${p}"
                done
                ;;
            *)
                warn "Cannot auto-install build prerequisites on ${PACKAGE_MANAGER}"
                return 1
                ;;
        esac
    fi
    return 0
}

build_from_source() {
    local tool="$1"
    local build_info
    build_info=$(check_build_from_source "${tool}" "" || true)
    
    if [[ "${build_info}" != BUILDABLE:* ]]; then
        warn "No source build recipe available for ${tool}"
        return 1
    fi
    
    local build_method
    local source_url
    build_method=$(echo "${build_info}" | cut -d: -f2)
    source_url=$(echo "${build_info}" | cut -d: -f3-)
    
    info "Building ${tool} from source using ${build_method} (${source_url})..."
    
    ensure_build_prerequisites "${build_method}" "${tool}" || true
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        info "[DRY RUN] Build ${tool} from ${source_url} via ${build_method}"
        return 0
    fi
    
    local build_dir="/tmp/kali-tools-build/${tool}"
    rm -rf "${build_dir}"
    mkdir -p "${build_dir}"
    
    local success=false
    case "${build_method}" in
        go)
            if command -v go &>/dev/null; then
                export GOPATH="${build_dir}/go"
                export GOBIN="/usr/local/bin"
                go install "${source_url}@latest" 2>&1 | tee -a "${LOG_FILE}" && success=true
            else
                warn "Go compiler is required to build ${tool} but not installed"
            fi
            ;;
        pip)
            local -a pip_cmd=()
            if command -v pip3 &>/dev/null; then
                pip_cmd=(pip3)
            elif command -v pip &>/dev/null; then
                pip_cmd=(pip)
            else
                warn "pip/pip3 is required to install ${tool} but not installed"
            fi
            if [[ ${#pip_cmd[@]} -gt 0 ]]; then
                local -a pip_args=("install" "--prefix=/usr/local")
                if "${pip_cmd[@]}" install --help 2>&1 | grep -q -- '--break-system-packages'; then
                    pip_args+=("--break-system-packages")
                fi
                "${pip_cmd[@]}" "${pip_args[@]}" "${tool}" 2>&1 | tee -a "${LOG_FILE}" && success=true
            fi
            ;;
        gem)
            if command -v gem &>/dev/null; then
                gem install "${tool}" 2>&1 | tee -a "${LOG_FILE}" && success=true
            else
                warn "Ruby gem is required to install ${tool} but not installed"
            fi
            ;;
        make|cmake)
            if command -v git &>/dev/null && command -v make &>/dev/null; then
                if git clone --depth 1 "${source_url}.git" "${build_dir}/src" 2>&1 | tee -a "${LOG_FILE}" || git clone --depth 1 "${source_url}" "${build_dir}/src" 2>&1 | tee -a "${LOG_FILE}"; then
                    pushd "${build_dir}/src" >/dev/null
                    if [[ -f "Makefile" ]]; then
                        { make && make install; } 2>&1 | tee -a "${LOG_FILE}" && success=true
                    elif [[ -f "CMakeLists.txt" ]] && command -v cmake &>/dev/null; then
                        { cmake -B build -DCMAKE_INSTALL_PREFIX=/usr/local && cmake --build build && cmake --install build; } 2>&1 | tee -a "${LOG_FILE}" && success=true
                    fi
                    popd >/dev/null
                fi
            else
                warn "git and make/cmake are required to build ${tool} but not installed"
            fi
            ;;
        git)
            if command -v git &>/dev/null; then
                if git clone --depth 1 "${source_url}" "/opt/${tool}" 2>&1 | tee -a "${LOG_FILE}"; then
                    if [[ -f "/opt/${tool}/${tool}.pl" ]]; then
                        ln -sf "/opt/${tool}/${tool}.pl" "/usr/local/bin/${tool}" && success=true
                    elif [[ -f "/opt/${tool}/${tool}.py" ]]; then
                        ln -sf "/opt/${tool}/${tool}.py" "/usr/local/bin/${tool}" && success=true
                    elif [[ -f "/opt/${tool}/${tool}.rb" ]]; then
                        ln -sf "/opt/${tool}/${tool}.rb" "/usr/local/bin/${tool}" && success=true
                    elif [[ -f "/opt/${tool}/${tool}" ]]; then
                        ln -sf "/opt/${tool}/${tool}" "/usr/local/bin/${tool}" && success=true
                    else
                        success=true
                    fi
                fi
            fi
            ;;
    esac
    
    rm -rf "${build_dir}"
    if [[ "${success}" == "true" ]]; then
        return 0
    else
        warn "Source build failed for ${tool}"
        return 1
    fi
}

run_precheck() {
    info "=== Package Availability Precheck (4-tier) ==="
    info "Distribution: ${DISTRO} (${DISTRO_FAMILY})"
    info "Package Manager: ${PACKAGE_MANAGER}"
    info "Tiers: official repos → AUR → pipx/pip → BlackArch"
    echo
    
    # PRECHECK_RESULTS entries: "TIER|tool|category|pkg"
    declare -ga PRECHECK_RESULTS=()
    
    update_package_db
    
    declare -g CURRENT_PRECHECK_TIER=""
    _precheck_tool() {
        local tool="$1"
        local category="${2:-unknown}"
        local pkg_name
        pkg_name=$(get_distro_pkg_name "${tool}")
        
        local tier
        if [[ -z "${pkg_name}" ]]; then
            tier=$(check_package_available "" "${tool}" || true)
            # check_package_available with empty pkg still checks pip/blackarch via tool arg
        else
            tier=$(check_package_available "${pkg_name}" "${tool}" || true)
        fi
        
        CURRENT_PRECHECK_TIER="${tier}"
        PRECHECK_RESULTS+=("${tier}|${tool}|${category}|${pkg_name:-}")
    }
    
    # ── Preset mode ─────────────────────────────────────────────────────────
    if [[ -n "${SELECTED_PRESET:-}" ]]; then
        if ! validate_preset "${SELECTED_PRESET}"; then
            error "Unknown preset: ${SELECTED_PRESET}"
            error "Available presets: $(get_presets | paste -sd, -)"
            exit 1
        fi
        local -a preset_tools=()
        read -ra preset_tools <<< "$(get_tools_in_preset "${SELECTED_PRESET}")"
        info "Checking preset '${SELECTED_PRESET}' (${#preset_tools[@]} tools)..."
        local p_official=0 p_aur=0 p_pipx=0 p_blackarch=0 p_missing=0
        
        for tool in "${preset_tools[@]}"; do
            local cat
            cat=$(get_tool_category "${tool}")
            _precheck_tool "${tool}" "${cat}"
            local tier="${CURRENT_PRECHECK_TIER}"
            case "${tier}" in
                OFFICIAL)  p_official=$((p_official + 1)); debug "  [OFFICIAL]  ${tool}" ;;
                AUR)       p_aur=$((p_aur + 1));           debug "  [AUR]       ${tool}" ;;
                PIPX)      p_pipx=$((p_pipx + 1));         debug "  [PIPX]      ${tool}" ;;
                BLACKARCH) p_blackarch=$((p_blackarch + 1)); debug "  [BLACKARCH] ${tool}" ;;
                *)         p_missing=$((p_missing + 1));   debug "  [MISSING]   ${tool}" ;;
            esac
        done
        
        local p_avail=$(( p_official + p_aur + p_pipx + p_blackarch ))
        local p_pct=0
        [[ ${#preset_tools[@]} -gt 0 ]] && p_pct=$((p_avail * 100 / ${#preset_tools[@]}))
        
        echo
        info "=== Precheck Summary (Preset: ${SELECTED_PRESET}) ==="
        info "Total tools: ${#preset_tools[@]}"
        success "Available in repos: ${p_avail} (${p_pct}%)"
        info "Official repos:     ${p_official}"
        [[ ${p_aur} -gt 0 ]]       && info  "AUR:                ${p_aur}"
        [[ ${p_pipx} -gt 0 ]]      && info  "pip/pipx (PyPI):    ${p_pipx}"
        [[ ${p_blackarch} -gt 0 ]] && warn  "BlackArch repo:     ${p_blackarch}"
        [[ ${p_missing} -gt 0 ]]   && error "Missing/unavail:    ${p_missing}"
        success "TOTAL AVAILABLE:    ${p_avail} / ${#preset_tools[@]} (${p_pct}%)"
        
        local -a p_deps=()
        mapfile -t p_deps < <(get_all_deps_for_tools "${preset_tools[@]}")
        [[ ${#p_deps[@]} -gt 0 ]] && info "Runtime deps required (${#p_deps[@]}): ${p_deps[*]}"
        
        export_report
        return 0
    fi
    
    # ── All-categories mode ──────────────────────────────────────────────────
    local total_tools=0 total_official=0 total_aur=0 total_pipx=0 total_blackarch=0 total_missing=0
    
    local categories=()
    if [[ ${#SELECTED_CATEGORIES[@]} -gt 0 ]]; then
        categories=("${SELECTED_CATEGORIES[@]}")
    else
        mapfile -t categories < <(get_categories)
    fi
    
    local -a all_checked_tools=()
    for cat in "${categories[@]}"; do
        local -a tools=()
        read -ra tools <<< "$(get_tools_in_category "${cat}")"
        all_checked_tools+=("${tools[@]}")
        
        local cat_total=${#tools[@]}
        local cat_official=0 cat_aur=0 cat_pipx=0 cat_blackarch=0 cat_missing=0
        local -a cat_missing_list=()
        
        total_tools=$((total_tools + cat_total))
        info "Checking category: ${cat} (${cat_total} tools)"
        
        for tool in "${tools[@]}"; do
            _precheck_tool "${tool}" "${cat}"
            local tier="${CURRENT_PRECHECK_TIER}"
            case "${tier}" in
                OFFICIAL)  cat_official=$((cat_official + 1)); total_official=$((total_official + 1)) ;;
                AUR)       cat_aur=$((cat_aur + 1));           total_aur=$((total_aur + 1)) ;;
                PIPX)      cat_pipx=$((cat_pipx + 1));         total_pipx=$((total_pipx + 1));
                           cat_missing_list+=("  [PIPX]      ${tool} → pip install $(get_tool_pip_pkg "${tool}")") ;;
                BLACKARCH) cat_blackarch=$((cat_blackarch + 1)); total_blackarch=$((total_blackarch + 1));
                           cat_missing_list+=("  [BLACKARCH] ${tool} → blackarch/$(get_tool_blackarch_pkg "${tool}")") ;;
                *)         cat_missing=$((cat_missing + 1));   total_missing=$((total_missing + 1));
                           cat_missing_list+=("  [MISSING]   ${tool}") ;;
            esac
        done
        
        local cat_avail=$(( cat_official + cat_aur + cat_pipx + cat_blackarch ))
        local cat_pct=0
        [[ ${cat_total} -gt 0 ]] && cat_pct=$((cat_avail * 100 / cat_total))
        
        echo
        info "  [${cat}] Total:${cat_total}  Official:${cat_official}  AUR:${cat_aur}  PIPX:${cat_pipx}  BlackArch:${cat_blackarch}  Missing:${cat_missing}  (${cat_pct}% available)"
        if [[ ${#cat_missing_list[@]} -gt 0 && ${#cat_missing_list[@]} -le 30 ]]; then
            for ml in "${cat_missing_list[@]}"; do
                info "  ${ml}"
            done
        fi
    done
    
    local total_avail=$(( total_official + total_aur + total_pipx + total_blackarch ))
    local total_pct=0
    [[ ${total_tools} -gt 0 ]] && total_pct=$((total_avail * 100 / total_tools))
    
    echo
    info "=== Precheck Summary (${DISTRO_FAMILY}) ==="
    info "Total tools:          ${total_tools}"
    success "Official repos:     ${total_official} ($(( total_official * 100 / (total_tools > 0 ? total_tools : 1) ))%)"
    info     "AUR:                ${total_aur} ($(( total_aur * 100 / (total_tools > 0 ? total_tools : 1) ))%)"
    info     "pip/pipx (PyPI):    ${total_pipx} ($(( total_pipx * 100 / (total_tools > 0 ? total_tools : 1) ))%)"
    warn     "BlackArch repo:     ${total_blackarch} ($(( total_blackarch * 100 / (total_tools > 0 ? total_tools : 1) ))%)"
    error    "Missing/unavail:    ${total_missing} ($(( total_missing * 100 / (total_tools > 0 ? total_tools : 1) ))%)"
    success "TOTAL AVAILABLE:    ${total_avail} / ${total_tools} (${total_pct}%)"
    
    local -a cat_deps=()
    mapfile -t cat_deps < <(get_all_deps_for_tools "${all_checked_tools[@]}")
    [[ ${#cat_deps[@]} -gt 0 ]] && info "Runtime deps identified (${#cat_deps[@]}): ${cat_deps[*]}"
    
    echo
    info "Use --dry-run --yes to see install plan without installing"
    info "BlackArch tools install automatically when --enable-blackarch is set or prompted"
    info "pip/pipx tools install via pipx or pip3 as a fallback tier"
    
    export_report
}

# ---------------------------------------------------------------------------
# export_report — write JSON or CSV availability/install report
# ---------------------------------------------------------------------------

export_report() {
    [[ -z "${EXPORT_REPORT_FILE:-}" ]] && return 0
    
    local format="json"
    [[ "${EXPORT_REPORT_FILE}" == *.csv ]] && format="csv"
    
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    
    local outdir
    outdir=$(dirname "${EXPORT_REPORT_FILE}")
    mkdir -p "${outdir}" 2>/dev/null || true
    
    # Determine source data: prefer PRECHECK_RESULTS, fall back to INSTALL_RESULTS
    local -a data_entries=()
    if [[ -n "${PRECHECK_RESULTS+x}" && ${#PRECHECK_RESULTS[@]} -gt 0 ]]; then
        data_entries=("${PRECHECK_RESULTS[@]}")
    elif [[ ${#INSTALL_RESULTS[@]} -gt 0 ]]; then
        # Convert INSTALL_RESULTS format to report format
        for r in "${INSTALL_RESULTS[@]}"; do
            local status="${r%%:*}"
            local rest="${r#*:}"
            local tname="${rest%% (*}"
            local cat
            cat=$(get_tool_category "${tname}" 2>/dev/null || echo "unknown")
            local pkg
            pkg=$(get_distro_pkg_name "${tname}" 2>/dev/null || echo "")
            data_entries+=("${status}|${tname}|${cat}|${pkg}")
        done
    fi
    
    case "${format}" in
        json)
            {
                printf '{\n'
                printf '  "generated": "%s",\n' "${timestamp}"
                printf '  "distro": "%s",\n' "${DISTRO:-unknown}"
                printf '  "distro_family": "%s",\n' "${DISTRO_FAMILY:-unknown}"
                printf '  "package_manager": "%s",\n' "${PACKAGE_MANAGER:-unknown}"
                printf '  "dry_run": %s,\n' "${DRY_RUN:-false}"
                printf '  "tools": [\n'
                local first=true
                for entry in "${data_entries[@]}"; do
                    IFS='|' read -r tier tname cat pkg <<< "${entry}"
                    [[ "${first}" == "true" ]] && first=false || printf ',\n'
                    printf '    {"name": "%s", "category": "%s", "status": "%s", "package": "%s"}' \
                        "${tname}" "${cat}" "${tier}" "${pkg}"
                done
                [[ "${first}" == "false" ]] && printf '\n'
                printf '  ]\n'
                printf '}\n'
            } > "${EXPORT_REPORT_FILE}"
            ;;
        csv)
            {
                printf 'name,category,status,package\n'
                for entry in "${data_entries[@]}"; do
                    IFS='|' read -r tier tname cat pkg <<< "${entry}"
                    printf '%s,%s,%s,%s\n' "${tname}" "${cat}" "${tier}" "${pkg}"
                done
            } > "${EXPORT_REPORT_FILE}"
            ;;
    esac
    
    success "Report exported → ${EXPORT_REPORT_FILE}"
}