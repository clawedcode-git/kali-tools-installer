#!/usr/bin/env bash
set -euo pipefail

parse_args() {
    declare -g FORCE_DISTRO
    declare -ga SELECTED_CATEGORIES
    declare -ga SELECTED_TOOLS
    declare -g DRY_RUN
    declare -g ASSUME_YES
    declare -g SKIP_UPDATE
    declare -g LIST_INSTALLED
    declare -g SHOW_HELP
    
    FORCE_DISTRO=""
    SELECTED_CATEGORIES=()
    SELECTED_TOOLS=()
    DRY_RUN=false
    ASSUME_YES=false
    SKIP_UPDATE=false
    LIST_INSTALLED=false
    SHOW_HELP=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --distro)
                FORCE_DISTRO="$2"
                export FORCE_DISTRO
                shift 2
                ;;
            --categories)
                IFS=',' read -ra SELECTED_CATEGORIES <<< "$2"
                shift 2
                ;;
            --tools)
                IFS=',' read -ra SELECTED_TOOLS <<< "$2"
                shift 2
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
            --log-file)
                LOG_FILE="$2"
                export LOG_FILE
                shift 2
                ;;
            --list-installed)
                LIST_INSTALLED=true
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
    
    export FORCE_DISTRO ASSUME_YES DRY_RUN SKIP_UPDATE LOG_FILE
}

print_help() {
    load_tool_list >/dev/null 2>&1 || true
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
    --distro <name>         Force distribution (arch, debian, fedora, slackware)
    --categories <list>     Comma-separated categories to install
    --tools <list>          Comma-separated specific tools to install
    --yes, -y               Skip confirmations
    --dry-run               Show packages without installing
    --no-update             Skip package database update
    --log-file <path>       Custom log location
    --list-installed        List installed Kali tools
    --help, -h              Show this help

Categories: $(get_categories | tr '\n' ', ' | sed 's/, $//')

Examples:
    sudo $(basename "$0")                          # Interactive
    sudo $(basename "$0") --distro arch --yes      # Non-interactive Arch
    sudo $(basename "$0") --distro slackware --yes # Non-interactive Slackware
    sudo $(basename "$0") --categories web,vuln --yes
    sudo $(basename "$0") --tools nmap,metasploit-framework --dry-run
EOF
}

select_installation_scope() {
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
            local tools
            tools=$(get_tools_in_category "${cat}")
            TOOLS_TO_INSTALL+=(${tools})
        done
        info "Selected categories: ${SELECTED_CATEGORIES[*]}"
        return
    fi
    
    print_banner
    echo
    info "Select installation scope:"
    echo "  1) All Kali tools (~600+ packages)"
    echo "  2) Select categories"
    echo "  3) Select specific tools"
    echo
    
    local choice
    choice=$(prompt_select "Choose option:" "All tools" "Select categories" "Select tools")
    
    case "${choice}" in
        "All tools")
            TOOLS_TO_INSTALL=($(list_all_tools))
            ;;
        "Select categories")
            select_categories_interactive
            ;;
        "Select tools")
            select_tools_interactive
            ;;
    esac
}

select_categories_interactive() {
    local categories=($(get_categories))
    echo "Available categories:"
    for i in "${!categories[@]}"; do
        local count
        count=$(echo "${CATEGORY_TOOLS[${categories[i]}]}" | wc -w)
        echo "  $((i+1))) ${categories[i]} (${count} tools)"
    done
    echo
    
    local input
    read -rp "Enter category numbers (comma-separated, or 'all'): " input
    
    if [[ "${input,,}" == "all" ]]; then
        TOOLS_TO_INSTALL=($(list_all_tools))
        return
    fi
    
    IFS=',' read -ra selections <<< "${input}"
    for sel in "${selections[@]}"; do
        sel=$(echo "${sel}" | xargs)
        if [[ "${sel}" =~ ^[0-9]+$ ]] && [[ ${sel} -ge 1 ]] && [[ ${sel} -le ${#categories[@]} ]]; then
            local cat="${categories[$((sel-1))]}"
            local tools
            tools=$(get_tools_in_category "${cat}")
            TOOLS_TO_INSTALL+=(${tools})
        fi
    done
}

select_tools_interactive() {
    local all_tools=($(list_all_tools))
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
        sel=$(echo "${sel}" | xargs)
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
        info "Dry run complete. Exiting."
        exit 0
    fi
    
    if ! prompt_yes_no "Proceed with installation?"; then
        info "Installation cancelled by user"
        exit 0
    fi
}

update_package_db() {
    if [[ "${SKIP_UPDATE}" == "true" ]]; then
        info "Skipping package database update (--no-update)"
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

install_package() {
    local tool="$1"
    local pkg_name
    pkg_name=$(get_distro_pkg_name "${tool}")
    
    if [[ -z "${pkg_name}" ]]; then
        warn "No package mapping for ${tool} on ${DISTRO_FAMILY}"
        INSTALL_RESULTS+=("SKIPPED:${tool} (no mapping)")
        return 1
    fi
    
    debug "Installing ${tool} (${pkg_name}) via ${PACKAGE_MANAGER}"
    
    local result=0
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
    
    if [[ ${result} -eq 0 ]]; then
        success "Installed: ${tool} (${pkg_name})"
        INSTALL_RESULTS+=("SUCCESS:${tool}")
    else
        error "Failed: ${tool} (${pkg_name})"
        INSTALL_RESULTS+=("FAILED:${tool}")
    fi
    
    return ${result}
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

run_installation() {
    update_package_db
    
    info "Starting installation of ${#TOOLS_TO_INSTALL[@]} tools..."
    
    local current=0
    for tool in "${TOOLS_TO_INSTALL[@]}"; do
        let current=current+1
        info "[${current}/${#TOOLS_TO_INSTALL[@]}] Installing ${tool}..."
        install_package "${tool}" || true
    done
}

list_installed_tools() {
    info "Checking installed Kali tools..."
    for tool in $(list_all_tools); do
        local pkg
        pkg=$(get_distro_pkg_name "${tool}")
        if [[ -n "${pkg}" ]]; then
            local installed=false
            case "${PACKAGE_MANAGER}" in
                pacman) pacman -Q "${pkg}" &>/dev/null && installed=true ;;
                apt) dpkg -l "${pkg}" 2>/dev/null | grep -q "^ii" && installed=true ;;
                dnf) rpm -q "${pkg}" &>/dev/null && installed=true ;;
                zypper) rpm -q "${pkg}" &>/dev/null && installed=true ;;
                apk) apk info -e "${pkg}" &>/dev/null && installed=true ;;
                slackpkg) slackpkg search installed "${pkg}" 2>/dev/null | grep -q "^${pkg}" && installed=true ;;
            esac
            if [[ "${installed}" == "true" ]]; then
                echo "${tool} (${pkg})"
            fi
        fi
    done
}