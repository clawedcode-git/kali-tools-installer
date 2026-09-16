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
    declare -g PRECHECK
    declare -g ENABLE_BLACKARCH
    declare -g SELECTED_PRESET
    
    FORCE_DISTRO=""
    SELECTED_CATEGORIES=()
    SELECTED_TOOLS=()
    SELECTED_PRESET=""
    DRY_RUN=false
    ASSUME_YES=false
    SKIP_UPDATE=false
    LIST_INSTALLED=false
    SHOW_HELP=false
    PRECHECK=false
    ENABLE_BLACKARCH=false
    
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
                IFS=',' read -ra SELECTED_CATEGORIES <<< "$2"
                shift 2
                ;;
            --tools)
                if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
                    error "Option $1 requires an argument"
                    print_help
                    exit 1
                fi
                IFS=',' read -ra SELECTED_TOOLS <<< "$2"
                shift 2
                ;;
            --preset)
                if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
                    error "Option $1 requires an argument"
                    print_help
                    exit 1
                fi
                SELECTED_PRESET="${2,,}"
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
            --no-deps|--skip-deps)
                INSTALL_DEPS=false
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
    
    export FORCE_DISTRO ASSUME_YES DRY_RUN SKIP_UPDATE LOG_FILE PRECHECK ENABLE_BLACKARCH SELECTED_PRESET INSTALL_DEPS
}

print_help() {
    load_tool_list >/dev/null 2>&1 || true
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
    --distro <name>         Force distribution (arch, debian, fedora, slackware, opensuse)
    --preset <name>         Install curated preset (top10, default, headless, web, wireless, passwords)
    --categories <list>     Comma-separated categories to install
    --tools <list>          Comma-separated specific tools to install
    --yes, -y               Skip confirmations
    --dry-run               Show packages without installing
    --no-update             Skip package database update
    --no-deps               Skip automatic dependency installation
    --enable-blackarch      Enable BlackArch repository on Arch/CachyOS
    --log-file <path>       Custom log location
    --list-installed        List installed Kali tools
    --precheck              Check package availability in repos (no install)
    --help, -h              Show this help

Presets: $(get_presets | paste -sd, -)
Categories: $(get_categories | paste -sd, -)

Examples:
    sudo $(basename "$0")                          # Interactive
    sudo $(basename "$0") --preset top10 --yes     # Install Top 10 Kali tools
    sudo $(basename "$0") --preset headless --yes  # Install headless CLI tools
    sudo $(basename "$0") --distro arch --yes      # Non-interactive Arch
    sudo $(basename "$0") --distro arch --enable-blackarch # With BlackArch repos
    sudo $(basename "$0") --distro slackware --yes # Non-interactive Slackware
    sudo $(basename "$0") --precheck --distro arch # Check package availability
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
    
    print_banner
    echo
    info "Select installation scope:"
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
    
    if ! prompt_yes_no "Proceed with installation?"; then
        info "Installation cancelled by user"
        exit 0
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

install_package() {
    local tool="$1"
    local pkg_name
    pkg_name=$(get_distro_pkg_name "${tool}")
    
    local result=0
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
    
    # If native pacman failed on Arch, try AUR helper (yay / paru)
    if [[ ${result} -ne 0 && "${PACKAGE_MANAGER}" == "pacman" && -n "${pkg_name}" ]]; then
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
    
    # If native package install failed or was unmapped, attempt source build fallback
    if [[ ${result} -ne 0 ]]; then
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
    fi
    
    if [[ ${result} -eq 0 ]]; then
        success "Installed: ${tool} (${pkg_name})"
        INSTALL_RESULTS+=("SUCCESS:${tool}")
    elif [[ -z "${pkg_name}" ]]; then
        warn "No package mapping for ${tool} on ${DISTRO_FAMILY}"
        INSTALL_RESULTS+=("SKIPPED:${tool} (no mapping)")
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

is_pkg_installed() {
    local pkg="$1"
    [[ -z "${pkg}" ]] && return 1
    
    case "${PACKAGE_MANAGER}" in
        pacman) pacman -Q "${pkg}" &>/dev/null ;;
        apt) dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q "ok installed" ;;
        dnf) rpm -q "${pkg}" &>/dev/null ;;
        zypper) rpm -q "${pkg}" &>/dev/null ;;
        apk) apk info -e "${pkg}" &>/dev/null ;;
        slackpkg) slackpkg search installed "${pkg}" 2>/dev/null | grep -q "^${pkg}" ;;
        emerge) qlist -I -e "${pkg}" &>/dev/null || equery which "${pkg}" &>/dev/null ;;
        xbps) xbps-query -s "${pkg}" &>/dev/null ;;
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
    
    for tool in "${TOOLS_TO_INSTALL[@]}"; do
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
    
    if [[ ${#mapped_tools[@]} -eq 0 ]]; then
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
    
    if [[ "${batch_supported}" == "true" ]]; then
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
            return 0
        fi
        warn "Batch installation failed (exit code ${batch_res}). Falling back to individual package installation..."
    fi
    
    local current=0
    for tool in "${mapped_tools[@]}"; do
        current=$((current + 1))
        info "[${current}/${#mapped_tools[@]}] Installing ${tool}..."
        install_package "${tool}" || true
    done
}

list_installed_tools() {
    info "Checking installed Kali tools..."
    local all_tools=()
    mapfile -t all_tools < <(list_all_tools)
    for tool in "${all_tools[@]}"; do
        local pkg
        pkg=$(get_distro_pkg_name "${tool}")
        if [[ -n "${pkg}" ]] && is_pkg_installed "${pkg}"; then
            echo "${tool} (${pkg})"
        fi
    done
}

check_package_available() {
    local pkg_name="$1"
    local available=false
    
    case "${PACKAGE_MANAGER}" in
        pacman)
            pacman -Si "${pkg_name}" &>/dev/null && available=true
            ;;
        apt)
            apt-cache show "${pkg_name}" &>/dev/null && available=true
            ;;
        dnf)
            { rpm -q "${pkg_name}" &>/dev/null || dnf info "${pkg_name}" &>/dev/null || dnf repoquery "${pkg_name}" &>/dev/null; } && available=true
            ;;
        zypper)
            zypper info "${pkg_name}" &>/dev/null && available=true
            ;;
        slackpkg)
            slackpkg search "${pkg_name}" 2>/dev/null | grep -q "${pkg_name}" && available=true
            ;;
        emerge)
            emerge --search "%@^${pkg_name}$" &>/dev/null && available=true
            ;;
        apk)
            apk info "${pkg_name}" &>/dev/null && available=true
            ;;
        xbps)
            xbps-query -R "${pkg_name}" &>/dev/null && available=true
            ;;
    esac
    
    if [[ "${available}" == "true" ]]; then
        return 0
    else
        return 1
    fi
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
            if command -v pip3 &>/dev/null; then
                pip3 install --prefix=/usr/local "${tool}" 2>&1 | tee -a "${LOG_FILE}" && success=true
            elif command -v pip &>/dev/null; then
                pip install --prefix=/usr/local "${tool}" 2>&1 | tee -a "${LOG_FILE}" && success=true
            else
                warn "pip/pip3 is required to install ${tool} but not installed"
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
                        make && make install 2>&1 | tee -a "${LOG_FILE}" && success=true
                    elif [[ -f "CMakeLists.txt" ]] && command -v cmake &>/dev/null; then
                        cmake -B build -DCMAKE_INSTALL_PREFIX=/usr/local && cmake --build build && cmake --install build 2>&1 | tee -a "${LOG_FILE}" && success=true
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
    info "=== Package Availability Precheck ==="
    info "Distribution: ${DISTRO} (${DISTRO_FAMILY})"
    info "Package Manager: ${PACKAGE_MANAGER}"
    echo
    
    update_package_db
    
    if [[ -n "${SELECTED_PRESET:-}" ]]; then
        if ! validate_preset "${SELECTED_PRESET}"; then
            error "Unknown preset: ${SELECTED_PRESET}"
            error "Available presets: $(get_presets | paste -sd, -)"
            exit 1
        fi
        local -a preset_tools=()
        read -ra preset_tools <<< "$(get_tools_in_preset "${SELECTED_PRESET}")"
        info "Checking preset '${SELECTED_PRESET}' (${#preset_tools[@]} tools)..."
        local p_available=0
        local p_missing=0
        local p_buildable=0
        local missing_tools=()
        for tool in "${preset_tools[@]}"; do
            local pkg_name
            pkg_name=$(get_distro_pkg_name "${tool}")
            if [[ -z "${pkg_name}" ]]; then
                p_missing=$((p_missing + 1))
                missing_tools+=("${tool} (no package mapping)")
                continue
            fi
            if check_package_available "${pkg_name}"; then
                p_available=$((p_available + 1))
            else
                p_missing=$((p_missing + 1))
                local build_res
                build_res=$(check_build_from_source "${tool}" "${pkg_name}" || true)
                if [[ "${build_res}" == BUILDABLE:* ]]; then
                    p_buildable=$((p_buildable + 1))
                    missing_tools+=("${tool} -> ${pkg_name} [BUILDABLE]")
                else
                    missing_tools+=("${tool} -> ${pkg_name}")
                fi
            fi
        done
        local p_pct=0
        [[ ${#preset_tools[@]} -gt 0 ]] && p_pct=$((p_available * 100 / ${#preset_tools[@]}))
        echo
        info "=== Precheck Summary (Preset: ${SELECTED_PRESET}) ==="
        info "Total tools: ${#preset_tools[@]}"
        success "Available in repos: ${p_available} (${p_pct}%)"
        [[ ${p_missing} -gt 0 ]] && error "Missing from repos: ${p_missing}"
        [[ ${p_buildable} -gt 0 ]] && warn "Potentially buildable from source: ${p_buildable}"
        local -a p_deps=()
        mapfile -t p_deps < <(get_all_deps_for_tools "${preset_tools[@]}")
        if [[ ${#p_deps[@]} -gt 0 ]]; then
            info "Runtime dependencies required (${#p_deps[@]}): ${p_deps[*]}"
        fi
        if [[ ${#missing_tools[@]} -gt 0 ]]; then
            info "Missing packages:"
            for mt in "${missing_tools[@]}"; do
                info "  - ${mt}"
            done
        fi
        return 0
    fi
    
    local total_tools=0
    local total_available=0
    local total_missing=0
    local total_buildable=0
    
    # Get categories to check - use selected if specified, otherwise all
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
        local cat_available=0
        local cat_missing=0
        local cat_buildable=0
        local missing_tools=()
        
        total_tools=$((total_tools + cat_total))
        
        info "Checking category: ${cat} (${cat_total} tools)"
        
        for tool in "${tools[@]}"; do
            local pkg_name
            pkg_name=$(get_distro_pkg_name "${tool}")
            
            if [[ -z "${pkg_name}" ]]; then
                cat_missing=$((cat_missing + 1))
                total_missing=$((total_missing + 1))
                missing_tools+=("${tool} (no package mapping)")
                continue
            fi
            
            if check_package_available "${pkg_name}"; then
                cat_available=$((cat_available + 1))
                total_available=$((total_available + 1))
                debug "  [AVAILABLE] ${tool} -> ${pkg_name}"
            else
                cat_missing=$((cat_missing + 1))
                total_missing=$((total_missing + 1))
                missing_tools+=("${tool} -> ${pkg_name}")
                
                # Check if buildable from source
                local build_result
                build_result=$(check_build_from_source "${tool}" "${pkg_name}" || true)
                if [[ "${build_result}" == BUILDABLE:* ]]; then
                    cat_buildable=$((cat_buildable + 1))
                    total_buildable=$((total_buildable + 1))
                    debug "  [MISSING but BUILDABLE] ${tool} -> ${pkg_name} (${build_result#BUILDABLE:})"
                else
                    debug "  [MISSING] ${tool} -> ${pkg_name}"
                fi
            fi
        done
        
        local cat_pct=0
        if [[ ${cat_total} -gt 0 ]]; then
            cat_pct=$((cat_available * 100 / cat_total))
        fi
        
        echo
        info "  Category: ${cat}"
        info "    Total: ${cat_total} | Available: ${cat_available} (${cat_pct}%) | Missing: ${cat_missing}"
        if [[ ${cat_buildable} -gt 0 ]]; then
            info "    Buildable from source: ${cat_buildable}"
        fi
        
        if [[ ${#missing_tools[@]} -gt 0 && ${cat_missing} -le 20 ]]; then
            info "    Missing packages:"
            for mt in "${missing_tools[@]}"; do
                info "      - ${mt}"
            done
        elif [[ ${cat_missing} -gt 20 ]]; then
            info "    Missing packages: ${cat_missing} (use --verbose to list all)"
        fi
    done
    
    local total_pct=0
    if [[ ${total_tools} -gt 0 ]]; then
        total_pct=$((total_available * 100 / total_tools))
    fi
    
    echo
    info "=== Precheck Summary ==="
    info "Total tools: ${total_tools}"
    success "Available in repos: ${total_available} (${total_pct}%)"
    error "Missing from repos: ${total_missing}"
    if [[ ${total_buildable} -gt 0 ]]; then
        warn "Potentially buildable from source: ${total_buildable}"
    fi
    local -a cat_deps=()
    mapfile -t cat_deps < <(get_all_deps_for_tools "${all_checked_tools[@]}")
    if [[ ${#cat_deps[@]} -gt 0 ]]; then
        info "Runtime dependencies identified (${#cat_deps[@]}): ${cat_deps[*]}"
    fi
    echo
    info "Use --dry-run --yes to see installation plan without building"
    info "For buildable packages, consider using AUR (Arch), COPR (Fedora), or manual compilation"
}