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
    
    FORCE_DISTRO=""
    SELECTED_CATEGORIES=()
    SELECTED_TOOLS=()
    DRY_RUN=false
    ASSUME_YES=false
    SKIP_UPDATE=false
    LIST_INSTALLED=false
    SHOW_HELP=false
    PRECHECK=false
    
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
            --precheck)
                PRECHECK=true
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
    
    export FORCE_DISTRO ASSUME_YES DRY_RUN SKIP_UPDATE LOG_FILE PRECHECK
}

print_help() {
    load_tool_list >/dev/null 2>&1 || true
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
    --distro <name>         Force distribution (arch, debian, fedora, slackware, opensuse)
    --categories <list>     Comma-separated categories to install
    --tools <list>          Comma-separated specific tools to install
    --yes, -y               Skip confirmations
    --dry-run               Show packages without installing
    --no-update             Skip package database update
    --log-file <path>       Custom log location
    --list-installed        List installed Kali tools
    --precheck              Check package availability in repos (no install)
    --help, -h              Show this help

Categories: $(get_categories | tr '\n' ', ' | sed 's/, $//')

Examples:
    sudo $(basename "$0")                          # Interactive
    sudo $(basename "$0") --distro arch --yes      # Non-interactive Arch
    sudo $(basename "$0") --distro slackware --yes # Non-interactive Slackware
    sudo $(basename "$0") --precheck --distro arch # Check package availability
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
    echo "  1) All Kali tools (~600+ packages)"
    echo "  2) Select categories"
    echo "  3) Select specific tools"
    echo
    
    local choice
    choice=$(prompt_select "Choose option:" "All tools" "Select categories" "Select tools")
    
    case "${choice}" in
        "All tools")
            mapfile -t TOOLS_TO_INSTALL < <(list_all_tools)
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
        sel=$(echo "${sel}" | xargs)
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
        if [[ -n "${pkg}" ]]; then
            local installed=false
            case "${PACKAGE_MANAGER}" in
                pacman) pacman -Q "${pkg}" &>/dev/null && installed=true ;;
                apt) dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q "ok installed" && installed=true ;;
                dnf) rpm -q "${pkg}" &>/dev/null && installed=true ;;
                zypper) rpm -q "${pkg}" &>/dev/null && installed=true ;;
                apk) apk info -e "${pkg}" &>/dev/null && installed=true ;;
                slackpkg) slackpkg search installed "${pkg}" 2>/dev/null | grep -q "^${pkg}" && installed=true ;;
                emerge) qlist -I -e "${pkg}" &>/dev/null || equery which "${pkg}" &>/dev/null && installed=true ;;
                xbps) xbps-query -s "${pkg}" &>/dev/null && installed=true ;;
            esac
            if [[ "${installed}" == "true" ]]; then
                echo "${tool} (${pkg})"
            fi
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
    local pkg_name="$2"
    local buildable=false
    local source_url=""
    local build_method=""
    
    case "${tool}" in
        # Tools commonly available via Go
        gobuster|gowitness|gobuster|feroxbuster)
            buildable=true
            build_method="go install"
            source_url="https://github.com/OJ/gobuster"
            ;;
        # Python-based tools
        wfuzz|whatweb|cewl|crunch|patator|patator|droopescan|sqlmap|wapiti)
            buildable=true
            build_method="pip install / python setup.py"
            source_url="https://github.com/$(echo ${tool} | tr '[:upper:]' '[:lower:]')"
            ;;
        # Tools with GitHub repos
        masscan|recon-ng|dnsrecon|fierce|dnsenum|dnswalk|lbhd|metagoofil|smtp-user-enum|snmpcheck|sslscan|sslyze|theharvester)
            buildable=true
            build_method="make / pip install / python setup.py"
            source_url="https://github.com/$(echo ${tool} | tr '[:upper:]' '[:lower:]')"
            ;;
        # Web tools
        dirb|gobuster|wfuzz|whatweb|wpscan|joomscan|cmsmap|nikto)
            buildable=true
            build_method="make / pip install"
            source_url="https://github.com/$(echo ${tool} | tr '[:upper:]' '[:lower:]')"
            ;;
        # Vulnerability tools
        sqlmap|sqlninja|bbqsql|jboss-autopwn|wapiti|skipfish|arachni|vagaa)
            buildable=true
            build_method="python setup.py / pip install"
            source_url="https://github.com/$(echo ${tool} | tr '[:upper:]' '[:lower:]')"
            ;;
        # Exploitation
        beef|powersploit|nishang|empire|covenant|sliver|koadic|pupy|ratel|setoolkit)
            buildable=true
            build_method="git clone + custom"
            source_url="https://github.com/$(echo ${tool} | tr '[:upper:]' '[:lower:]')"
            ;;
        # Password
        hashcat|john|hydra|medusa|ncrack|patator|crowbar|cewl|crunch|cupp|rsmangler|maskprocessor|statsprocessor|princeprocessor)
            buildable=true
            build_method="make / cmake"
            source_url="https://github.com/$(echo ${tool} | tr '[:upper:]' '[:lower:]')"
            ;;
        # Wireless
        wifite|bully|pixiewps|fern-wifi-cracker|wifi-honey|hostapd-wpe|eaphammer|fluxion|wifiphisher|create_ap|mdk3|mdk4)
            buildable=true
            build_method="make / python setup.py"
            source_url="https://github.com/$(echo ${tool} | tr '[:upper:]' '[:lower:]')"
            ;;
        # Forensics
        volatility|volatility3|bulk-extractor|foremost|scalpel|binwalk|firmwalker|firmadyne)
            buildable=true
            build_method="python setup.py / make"
            source_url="https://github.com/$(echo ${tool} | tr '[:upper:]' '[:lower:]')"
            ;;
        # Reverse
        ghidra|radare2|cutter|rizin|angr|pwntools|ropper|ropgadget|one-gadget|checksec|pwninit|gef|pwndbg|peda)
            buildable=true
            build_method="make / pip install / gradle"
            source_url="https://github.com/$(echo ${tool} | tr '[:upper:]' '[:lower:]')"
            ;;
        # Hardware
        rtl-sdr|hackrf|ubertooth|yardstick|bladeRF|limesdr|gqrx|cubicsdr|sdrangel|inspectrum|sigrok|pulseview)
            buildable=true
            build_method="cmake / make"
            source_url="https://github.com/$(echo ${tool} | tr '[:upper:]' '[:lower:]')"
            ;;
        # Reporting
        faraday|dradis|magictree)
            buildable=true
            build_method="gem install / docker"
            source_url="https://github.com/$(echo ${tool} | tr '[:upper:]' '[:lower:]')"
            ;;
        # Sniffing
        driftnet|urlsnarf|msgsnarf|mailsnarf|webspy|sslsniff|tcpick|tcpxtract|chaosreader|arpalert|arpon|netdiscover|nbtscan|onesixtyone|ike-scan|cdpsnarf|dtpscan|yersinia)
            buildable=true
            build_method="make / python setup.py"
            source_url="https://github.com/$(echo ${tool} | tr '[:upper:]' '[:lower:]')"
            ;;
        # Maintaining
        proxychains|proxytunnel|sslh|stunnel|socat|cryptcat|sbd|dns2tcp|iodine|ptunnel|tcptunnel|udptunnel)
            buildable=true
            build_method="make / cmake"
            source_url="https://github.com/$(echo ${tool} | tr '[:upper:]' '[:lower:]')"
            ;;
        *)
            # Default: check if it's a known GitHub repo
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

run_precheck() {
    info "=== Package Availability Precheck ==="
    info "Distribution: ${DISTRO} (${DISTRO_FAMILY})"
    info "Package Manager: ${PACKAGE_MANAGER}"
    echo
    
    update_package_db
    
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
    
    for cat in "${categories[@]}"; do
        local -a tools=()
        read -ra tools <<< "$(get_tools_in_category "${cat}")"
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
    echo
    info "Use --dry-run --yes to see installation plan without building"
    info "For buildable packages, consider using AUR (Arch), COPR (Fedora), or manual compilation"
}