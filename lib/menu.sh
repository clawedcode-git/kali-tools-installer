#!/usr/bin/env bash
set -euo pipefail

bbs_main_menu() {
    while true; do
        clear 2>/dev/null || true
        print_banner
        echo
        bbs_box_header "MAIN SELECTION MENU"
        echo
        echo -e "  ${GREEN}[1]${NC}  ⚡ Quick Presets (top10, default, headless, web...)"
        echo -e "  ${GREEN}[2]${NC}  📦 Category Explorer (info, vuln, web, password...)"
        echo -e "  ${GREEN}[3]${NC}  🔍 Select Specific Tools (~171 Available)"
        echo -e "  ${GREEN}[4]${NC}  🚀 Install All 171 Kali Tools"
        echo -e "  ${GREEN}[5]${NC}  🔎 Repository Availability Precheck"
        echo -e "  ${GREEN}[6]${NC}  🗑️  Tool Uninstallation & Cleanup Engine"
        echo -e "  ${GREEN}[7]${NC}  📋 View Currently Installed Tools"
        echo -e "  ${GREEN}[8]${NC}  ⚙️  Toggle Options (Dry-Run: ${YELLOW}${DRY_RUN}${NC}, Deps: ${YELLOW}${INSTALL_DEPS}${NC})"
        echo -e "  ${RED}[Q]${NC}  🚪 Exit Installer"
        echo
        echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
        
        local choice
        choice=$(bbs_read_key "  Select an option [1-8, Q]: ")
        echo
        
        case "${choice,,}" in
            1)
                if bbs_preset_menu; then
                    return 0
                fi
                ;;
            2)
                if bbs_category_menu; then
                    return 0
                fi
                ;;
            3)
                if bbs_tools_menu; then
                    return 0
                fi
                ;;
            4)
                SELECTED_PRESET=""
                SELECTED_CATEGORIES=()
                SELECTED_TOOLS=()
                read -ra TOOLS_TO_INSTALL <<< "$(list_all_tools)"
                info "Selected all tools (${#TOOLS_TO_INSTALL[@]} tools)"
                return 0
                ;;
            5)
                echo
                info "Running package availability precheck across all categories..."
                PRECHECK=true
                run_precheck
                echo
                read -rp "  Press [Enter] to return to menu..." _
                ;;
            6)
                UNINSTALL=true
                echo
                info "Entering Uninstallation & Cleanup Engine"
                if bbs_uninstall_menu; then
                    return 0
                fi
                ;;
            7)
                echo
                list_installed_tools
                echo
                read -rp "  Press [Enter] to return to menu..." _
                ;;
            8)
                bbs_toggle_options_menu
                ;;
            q)
                echo
                info "Exiting Kali Tools Installer."
                exit 0
                ;;
            *)
                # Invalid option, re-loop
                ;;
        esac
    done
}

bbs_preset_menu() {
    while true; do
        clear 2>/dev/null || true
        print_banner
        echo
        bbs_box_header "TOOL BUNDLES & PRESETS"
        echo
        echo -e "  ${GREEN}[1]${NC}  top10      Essential Kali Top 10 pentesting tools (10)"
        echo -e "  ${GREEN}[2]${NC}  default    Core Kali default pentesting suite (35)"
        echo -e "  ${GREEN}[3]${NC}  headless   CLI-only suite for remote servers/VPS (32)"
        echo -e "  ${GREEN}[4]${NC}  web        Web application security assessment (10)"
        echo -e "  ${GREEN}[5]${NC}  wireless   Wireless network auditing & attacks (10)"
        echo -e "  ${GREEN}[6]${NC}  passwords  Password cracking & wordlists (8)"
        echo -e "  ${YELLOW}[B]${NC}  Back to Main Menu"
        echo
        echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
        
        local choice
        choice=$(bbs_read_key "  Select preset [1-6, B]: ")
        echo
        
        case "${choice,,}" in
            1) SELECTED_PRESET="top10" ;;
            2) SELECTED_PRESET="default" ;;
            3) SELECTED_PRESET="headless" ;;
            4) SELECTED_PRESET="web" ;;
            5) SELECTED_PRESET="wireless" ;;
            6) SELECTED_PRESET="passwords" ;;
            b) return 1 ;;
            *) continue ;;
        esac
        
        SELECTED_TOOLS=()
        SELECTED_CATEGORIES=()
        read -ra TOOLS_TO_INSTALL <<< "$(get_tools_in_preset "${SELECTED_PRESET}")"
        info "Selected preset '${SELECTED_PRESET}' (${#TOOLS_TO_INSTALL[@]} tools)"
        return 0
    done
}

bbs_category_menu() {
    while true; do
        clear 2>/dev/null || true
        print_banner
        echo
        bbs_box_header "SECURITY TOOL CATEGORIES"
        echo
        echo -e "  ${GREEN}[1]${NC} info (23)        ${GREEN}[2]${NC} vuln (12)       ${GREEN}[3]${NC} web (10)"
        echo -e "  ${GREEN}[4]${NC} password (18)    ${GREEN}[5]${NC} wireless (15)   ${GREEN}[6]${NC} exploit (14)"
        echo -e "  ${GREEN}[7]${NC} forensics (16)   ${GREEN}[8]${NC} reverse (11)    ${GREEN}[9]${NC} sniffing (12)"
        echo -e "  ${GREEN}[0]${NC} hardware (4)     ${GREEN}[M]${NC} maintaining (3) ${GREEN}[R]${NC} reporting (3)"
        echo -e "  ${CYAN}[A]${NC} All Categories (~171 tools)"
        echo -e "  ${YELLOW}[B]${NC} Back to Main Menu"
        echo
        echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
        
        local choice
        choice=$(bbs_read_key "  Select category [0-9, M, R, A, B]: ")
        echo
        
        local cat=""
        case "${choice,,}" in
            1) cat="info" ;;
            2) cat="vuln" ;;
            3) cat="web" ;;
            4) cat="password" ;;
            5) cat="wireless" ;;
            6) cat="exploit" ;;
            7) cat="forensics" ;;
            8) cat="reverse" ;;
            9) cat="sniffing" ;;
            0) cat="hardware" ;;
            m) cat="maintaining" ;;
            r) cat="reporting" ;;
            a)
                SELECTED_PRESET=""
                SELECTED_TOOLS=()
                read -ra SELECTED_CATEGORIES <<< "$(get_categories)"
                read -ra TOOLS_TO_INSTALL <<< "$(list_all_tools)"
                info "Selected all categories (${#TOOLS_TO_INSTALL[@]} tools)"
                return 0
                ;;
            b) return 1 ;;
            *) continue ;;
        esac
        
        SELECTED_PRESET=""
        SELECTED_TOOLS=()
        SELECTED_CATEGORIES=("${cat}")
        read -ra TOOLS_TO_INSTALL <<< "$(get_tools_in_category "${cat}")"
        info "Selected category '${cat}' (${#TOOLS_TO_INSTALL[@]} tools)"
        return 0
    done
}

bbs_tools_menu() {
    clear 2>/dev/null || true
    print_banner
    echo
    bbs_box_header "SELECT SPECIFIC TOOLS"
    echo
    echo -e "  Enter one or more tool names separated by commas."
    echo -e "  ${CYAN}Example:${NC} nmap, wireshark, burpsuite, john"
    echo -e "  (Leave empty or type 'B' to return to Main Menu)"
    echo
    echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
    
    local input
    read -rp "  Tools: " input
    input="${input#"${input%%[![:space:]]*}"}"
    input="${input%"${input##*[![:space:]]}"}"
    
    if [[ -z "${input}" || "${input,,}" == "b" ]]; then
        return 1
    fi
    
    IFS=',' read -ra SELECTED_TOOLS <<< "${input}"
    local -a valid_tools=()
    for tool in "${SELECTED_TOOLS[@]}"; do
        tool="${tool#"${tool%%[![:space:]]*}"}"
        tool="${tool%"${tool##*[![:space:]]}"}"
        if [[ -n "${tool}" ]]; then
            if validate_tool "${tool}"; then
                valid_tools+=("${tool}")
            else
                warn "Ignoring unknown tool: ${tool}"
            fi
        fi
    done
    
    if [[ ${#valid_tools[@]} -eq 0 ]]; then
        error "No valid tools specified."
        read -rp "  Press [Enter] to continue..." _
        return 1
    fi
    
    SELECTED_PRESET=""
    SELECTED_CATEGORIES=()
    SELECTED_TOOLS=("${valid_tools[@]}")
    TOOLS_TO_INSTALL=("${valid_tools[@]}")
    info "Selected ${#TOOLS_TO_INSTALL[@]} specific tools: ${TOOLS_TO_INSTALL[*]}"
    return 0
}

bbs_uninstall_menu() {
    while true; do
        clear 2>/dev/null || true
        print_banner
        echo
        bbs_box_header "UNINSTALLATION SCOPE"
        echo
        echo -e "  Select what you would like to uninstall:"
        echo -e "  ${GREEN}[1]${NC}  Uninstall by Preset (top10, headless, web...)"
        echo -e "  ${GREEN}[2]${NC}  Uninstall by Category"
        echo -e "  ${GREEN}[3]${NC}  Uninstall Specific Tools"
        echo -e "  ${YELLOW}[B]${NC}  Back to Main Menu"
        echo
        echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
        
        local choice
        choice=$(bbs_read_key "  Select option [1-3, B]: ")
        echo
        
        case "${choice,,}" in
            1)
                if bbs_preset_menu; then
                    return 0
                fi
                ;;
            2)
                if bbs_category_menu; then
                    return 0
                fi
                ;;
            3)
                if bbs_tools_menu; then
                    return 0
                fi
                ;;
            b)
                UNINSTALL=false
                return 1
                ;;
            *) continue ;;
        esac
    done
}

bbs_toggle_options_menu() {
    while true; do
        clear 2>/dev/null || true
        print_banner
        echo
        bbs_box_header "INSTALLER OPTIONS & SETTINGS"
        echo
        echo -e "  ${GREEN}[1]${NC}  Toggle Dry-Run Mode           (Currently: ${YELLOW}${DRY_RUN}${NC})"
        echo -e "  ${GREEN}[2]${NC}  Toggle Dependency Resolution  (Currently: ${YELLOW}${INSTALL_DEPS}${NC})"
        echo -e "  ${GREEN}[3]${NC}  Toggle BlackArch Repository   (Currently: ${YELLOW}${ENABLE_BLACKARCH}${NC})"
        echo -e "  ${GREEN}[4]${NC}  Toggle Skip Repo Update       (Currently: ${YELLOW}${SKIP_UPDATE}${NC})"
        echo -e "  ${YELLOW}[B]${NC}  Back to Main Menu"
        echo
        echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
        
        local choice
        choice=$(bbs_read_key "  Select setting to toggle [1-4, B]: ")
        echo
        
        case "${choice,,}" in
            1)
                if [[ "${DRY_RUN}" == "true" ]]; then
                    DRY_RUN=false
                else
                    DRY_RUN=true
                fi
                ;;
            2)
                if [[ "${INSTALL_DEPS}" == "true" ]]; then
                    INSTALL_DEPS=false
                else
                    INSTALL_DEPS=true
                fi
                ;;
            3)
                if [[ "${ENABLE_BLACKARCH}" == "true" ]]; then
                    ENABLE_BLACKARCH=false
                else
                    ENABLE_BLACKARCH=true
                fi
                ;;
            4)
                if [[ "${SKIP_UPDATE}" == "true" ]]; then
                    SKIP_UPDATE=false
                else
                    SKIP_UPDATE=true
                fi
                ;;
            b) return 0 ;;
            *) continue ;;
        esac
    done
}

bbs_confirm_dialog() {
    local action="${1:-Installation}"
    local target_scope="${2:-${#TOOLS_TO_INSTALL[@]} tools}"
    
    if [[ "${ASSUME_YES:-false}" == "true" ]]; then
        return 0
    fi
    
    if [[ ! -t 0 || "${NO_TUI:-false}" == "true" ]]; then
        prompt_yes_no "Proceed with ${action} of ${target_scope}?" "y"
        return $?
    fi
    
    echo
    bbs_box_header "${action^^} CONFIRMATION"
    echo
    echo -e "  Target Distribution : ${CYAN}${DISTRO:-unknown} (${PACKAGE_MANAGER:-pacman})${NC}"
    echo -e "  Target Scope        : ${CYAN}${target_scope}${NC}"
    echo -e "  Total Packages      : ${GREEN}${#TOOLS_TO_INSTALL[@]} packages${NC}"
    echo -e "  Dependencies Mode   : ${YELLOW}${INSTALL_DEPS}${NC}"
    echo -e "  Dry-Run Preview     : ${YELLOW}${DRY_RUN}${NC}"
    echo -e "  Log Destination     : ${LOG_FILE}"
    echo
    echo -e "${BLUE}─────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${GREEN}[Y]${NC} Yes, proceed with ${action,,}"
    echo -e "  ${RED}[N]${NC} No, cancel and return"
    echo
    
    local key
    key=$(bbs_read_key "  Confirmation [Y/n]: ")
    echo
    
    if [[ -z "${key}" || "${key,,}" =~ ^y ]]; then
        return 0
    else
        return 1
    fi
}
