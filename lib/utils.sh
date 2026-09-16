#!/usr/bin/env bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
readonly KALI_TOOLS_LIST="${PROJECT_ROOT}/config/kali-tools.list"

LOG_FILE="${LOG_FILE:-/var/log/kali-tools-install.log}"
CONFIG_FILE="${CONFIG_FILE:-}"
DEFAULT_CONFIG_SYSTEM="${DEFAULT_CONFIG_SYSTEM:-/etc/kali-installer/config}"
DEFAULT_CONFIG_USER="${DEFAULT_CONFIG_USER:-${XDG_CONFIG_HOME:-${HOME:-}/.config}/kali-installer/config}"
DISTRO=""
DISTRO_FAMILY=""
PACKAGE_MANAGER=""
SELECTED_CATEGORIES=()
SELECTED_TOOLS=()
SELECTED_PRESET=""
DRY_RUN=false
ASSUME_YES="${ASSUME_YES:-false}"
SKIP_UPDATE=false
ENABLE_BLACKARCH="${ENABLE_BLACKARCH:-false}"
INSTALL_DEPS="${INSTALL_DEPS:-true}"
UNINSTALL="${UNINSTALL:-false}"
NO_TUI="${NO_TUI:-false}"
TOOLS_TO_INSTALL=()
INSTALL_RESULTS=()
EXPORT_REPORT_FILE="${EXPORT_REPORT_FILE:-}"
UPDATE_MODE="${UPDATE_MODE:-false}"
DIFF_MODE="${DIFF_MODE:-false}"
declare -gA TOOL_METHOD_OVERRIDES=([_init]="")

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local terminal_output="${timestamp} [${level}] ${msg}"
    if [[ -n "${LOG_FILE:-}" ]] && { [[ -w "${LOG_FILE}" ]] || touch "${LOG_FILE}" 2>/dev/null; }; then
        local clean_output
        clean_output=$(printf '%b' "${terminal_output}" | sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g')
        echo "${clean_output}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
    if [[ -t 1 ]]; then
        echo -e "${terminal_output}"
    else
        printf '%b\n' "${terminal_output}" | sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g'
    fi
}

info() { log "INFO" "${BLUE}$*${NC}"; }
warn() { log "WARN" "${YELLOW}$*${NC}"; }
error() { log "ERROR" "${RED}$*${NC}"; }
success() { log "SUCCESS" "${GREEN}$*${NC}"; }
debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        log "DEBUG" "${CYAN}$*${NC}"
    fi
}

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local reply
    if [[ "${ASSUME_YES}" == "true" ]]; then
        return 0
    fi
    local prompt_suffix="[y/N]"
    if [[ "${default,,}" =~ ^y ]]; then
        prompt_suffix="[Y/n]"
    fi
    read -rp "${prompt} ${prompt_suffix}: " reply
    reply="${reply:-$default}"
    [[ "${reply,,}" =~ ^y ]]
}

prompt_select() {
    local prompt="$1"
    shift
    local options=("$@")
    local choice
    if [[ "${ASSUME_YES}" == "true" ]]; then
        echo "${options[0]}"
        return 0
    fi
    local PS3="${prompt} "
    select choice in "${options[@]}"; do
        [[ -n "${choice}" ]] && { echo "${choice}"; return 0; }
        echo "Invalid selection"
    done
}

load_config_file() {
    local config_file="$1"
    [[ ! -f "${config_file}" ]] && return 0
    
    local line
    while IFS= read -r line || [[ -n "${line}" ]]; do
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        
        [[ -z "${line}" || "${line}" =~ ^# || "${line}" =~ ^\; ]] && continue
        [[ "${line}" != *"="* ]] && continue
        
        local key="${line%%=*}"
        local val="${line#*=}"
        
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        val="${val#"${val%%[![:space:]]*}"}"
        val="${val%"${val##*[![:space:]]}"}"
        
        if [[ "${val}" =~ ^\"(.*)\"[[:space:]]*(#.*|\;.*)?$ ]]; then
            val="${BASH_REMATCH[1]}"
        elif [[ "${val}" =~ ^\'(.*)\'[[:space:]]*(#.*|\;.*)?$ ]]; then
            val="${BASH_REMATCH[1]}"
        else
            val="${val%%#*}"
            val="${val%%;*}"
            val="${val%"${val##*[![:space:]]}"}"
        fi
        
        local norm_key="${key,,}"
        norm_key="${norm_key//-/_}"
        
        case "${norm_key}" in
            distro|force_distro)
                FORCE_DISTRO="${val,,}"
                ;;
            preset)
                SELECTED_PRESET="${val,,}"
                ;;
            categories|category)
                IFS=',' read -ra SELECTED_CATEGORIES <<< "$val"
                for i in "${!SELECTED_CATEGORIES[@]}"; do
                    local item="${SELECTED_CATEGORIES[$i]}"
                    item="${item#"${item%%[![:space:]]*}"}"
                    item="${item%"${item##*[![:space:]]}"}"
                    SELECTED_CATEGORIES[$i]="${item}"
                done
                ;;
            tools|tool)
                IFS=',' read -ra SELECTED_TOOLS <<< "$val"
                for i in "${!SELECTED_TOOLS[@]}"; do
                    local item="${SELECTED_TOOLS[$i]}"
                    item="${item#"${item%%[![:space:]]*}"}"
                    item="${item%"${item##*[![:space:]]}"}"
                    SELECTED_TOOLS[$i]="${item}"
                done
                ;;
            enable_blackarch)
                if [[ "${val,,}" =~ ^(true|yes|1)$ ]]; then
                    ENABLE_BLACKARCH=true
                else
                    ENABLE_BLACKARCH=false
                fi
                ;;
            no_update|skip_update)
                if [[ "${val,,}" =~ ^(true|yes|1)$ ]]; then
                    SKIP_UPDATE=true
                else
                    SKIP_UPDATE=false
                fi
                ;;
            install_deps)
                if [[ "${val,,}" =~ ^(false|no|0)$ ]]; then
                    INSTALL_DEPS=false
                else
                    INSTALL_DEPS=true
                fi
                ;;
            no_deps|skip_deps)
                if [[ "${val,,}" =~ ^(true|yes|1)$ ]]; then
                    INSTALL_DEPS=false
                else
                    INSTALL_DEPS=true
                fi
                ;;
            log_file)
                LOG_FILE="${val}"
                ;;
            yes|assume_yes)
                if [[ "${val,,}" =~ ^(true|yes|1)$ ]]; then
                    ASSUME_YES=true
                else
                    ASSUME_YES=false
                fi
                ;;
            dry_run)
                if [[ "${val,,}" =~ ^(true|yes|1)$ ]]; then
                    DRY_RUN=true
                else
                    DRY_RUN=false
                fi
                ;;
            precheck)
                if [[ "${val,,}" =~ ^(true|yes|1)$ ]]; then
                    PRECHECK=true
                else
                    PRECHECK=false
                fi
                ;;
            uninstall|remove)
                if [[ "${val,,}" =~ ^(true|yes|1)$ ]]; then
                    UNINSTALL=true
                else
                    UNINSTALL=false
                fi
                ;;
            no_tui|plain)
                if [[ "${val,,}" =~ ^(true|yes|1)$ ]]; then
                    NO_TUI=true
                else
                    NO_TUI=false
                fi
                ;;
            export_report|report_file)
                EXPORT_REPORT_FILE="${val}"
                ;;
            update|auto_update)
                if [[ "${val,,}" =~ ^(true|yes|1)$ ]]; then
                    UPDATE_MODE=true
                else
                    UPDATE_MODE=false
                fi
                ;;
            diff|diff_mode)
                if [[ "${val,,}" =~ ^(true|yes|1)$ ]]; then
                    DIFF_MODE=true
                else
                    DIFF_MODE=false
                fi
                ;;
            method_override|override_method|method_overrides)
                local -a pairs=()
                IFS=',' read -ra pairs <<< "${val}"
                for pair in "${pairs[@]}"; do
                    pair="${pair#"${pair%%[![:space:]]*}"}"
                    pair="${pair%"${pair##*[![:space:]]}"}"
                    if [[ "${pair}" == *":"* ]]; then
                        local t_name="${pair%%:*}"
                        local m_name="${pair#*:}"
                        t_name="${t_name#"${t_name%%[![:space:]]*}"}"
                        t_name="${t_name%"${t_name##*[![:space:]]}"}"
                        m_name="${m_name#"${m_name%%[![:space:]]*}"}"
                        m_name="${m_name%"${m_name##*[![:space:]]}"}"
                        [[ -n "${t_name}" && -n "${m_name}" ]] && TOOL_METHOD_OVERRIDES["${t_name}"]="${m_name}"
                    fi
                done
                ;;
            override.*|override_*)
                local t_name=""
                if [[ "${key}" == override.* ]]; then
                    t_name="${key#override.}"
                else
                    t_name="${key#override_}"
                fi
                t_name="${t_name#"${t_name%%[![:space:]]*}"}"
                t_name="${t_name%"${t_name##*[![:space:]]}"}"
                [[ -n "${t_name}" ]] && TOOL_METHOD_OVERRIDES["${t_name}"]="${val}"
                ;;
            *)
                debug "Unknown configuration key: ${key}"
                ;;
        esac
    done < "${config_file}"
}

load_default_configs() {
    local custom_config=""
    local prev=""
    for arg in "$@"; do
        if [[ "${prev}" == "--config" ]]; then
            if [[ -n "${arg}" && "${arg}" != --* ]]; then
                custom_config="${arg}"
            fi
            prev=""
        elif [[ "${arg}" == --config=* ]]; then
            custom_config="${arg#--config=}"
        elif [[ "${arg}" == "--config" ]]; then
            prev="--config"
        fi
    done
    
    # 1. System-wide configuration
    local sys_config="${DEFAULT_CONFIG_SYSTEM:-/etc/kali-installer/config}"
    if [[ -n "${sys_config}" && -f "${sys_config}" ]]; then
        load_config_file "${sys_config}"
        CONFIG_FILE="${sys_config}"
    fi
    
    # 2. User configuration
    local user_config="${DEFAULT_CONFIG_USER:-${XDG_CONFIG_HOME:-${HOME:-}/.config}/kali-installer/config}"
    if [[ -n "${user_config}" && -f "${user_config}" ]]; then
        load_config_file "${user_config}"
        CONFIG_FILE="${user_config}"
    fi
    
    # 3. Custom configuration passed via CLI
    if [[ -n "${custom_config}" ]]; then
        if [[ ! -f "${custom_config}" ]]; then
            error "Configuration file not found: ${custom_config}"
            exit 1
        fi
        load_config_file "${custom_config}"
        CONFIG_FILE="${custom_config}"
    fi
}

init_logging() {
    LOG_FILE="${LOG_FILE:-/var/log/kali-tools-install.log}"
    if ! mkdir -p "$(dirname "${LOG_FILE}")" 2>/dev/null || ! touch "${LOG_FILE}" 2>/dev/null; then
        local fallback_log="/tmp/kali-tools-install-${UID:-user}.log"
        warn "Cannot write to ${LOG_FILE}, falling back to ${fallback_log}"
        LOG_FILE="${fallback_log}"
        touch "${LOG_FILE}" 2>/dev/null || true
    fi
    info "=== Kali Tools Installer Started ==="
    info "Log file: ${LOG_FILE}"
    if [[ -n "${CONFIG_FILE:-}" ]]; then
        info "Config file: ${CONFIG_FILE}"
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
}

print_banner() {
    local os_name="${DISTRO_NAME:-${DISTRO:-Detecting...}}"
    local os_badge="${os_name}"
    if [[ -n "${DISTRO_FAMILY:-}" && "${os_name}" != "${DISTRO_FAMILY}" ]]; then
        os_badge="${os_name} (${DISTRO_FAMILY})"
    fi
    local pkg_badge="${PACKAGE_MANAGER:-auto}"
    local ba_badge="Disabled"
    if [[ "${ENABLE_BLACKARCH:-false}" == "true" ]]; then
        ba_badge="Enabled"
    fi
    local tool_count=171
    if [[ -n "${TOOL_CATEGORIES+x}" && ${#TOOL_CATEGORIES[@]} -gt 0 ]]; then
        tool_count="${#TOOL_CATEGORIES[@]}"
    fi
    local deps_badge="Auto"
    if [[ "${INSTALL_DEPS:-true}" != "true" ]]; then
        deps_badge="Skipped"
    fi

    # Truncate field values to prevent layout distortion
    local os_val="${os_badge:0:14}"
    local pkg_val="${pkg_badge:0:10}"
    local ba_val="${ba_badge:0:8}"
    local tools_val="${tool_count} Total"
    tools_val="${tools_val:0:11}"
    local presets_val="6 Curated"
    presets_val="${presets_val:0:9}"
    local deps_val="${deps_badge:0:13}"

    if [[ -t 1 && "${NO_TUI:-false}" != "true" ]]; then
        cat << EOF
${CYAN}             _  __     _ _   _____           _       ${NC}
${CYAN}            | |/ /__ _| (_) |_   _|__   ___ | |___   ${NC}
${CYAN}            | ' // _\` | | |   | |/ _ \ / _ \| / __|  ${NC}
${CYAN}            | . \ (_| | | |   | | (_) | (_) | \__ \  ${NC}
${CYAN}            |_|\_\__,_|_|_|   |_|\___/ \___/|_|___/  ${NC}
${YELLOW}                   [ OFFENSIVE SECURITY TOOLSET ]    ${NC}
${BLUE}┌───────────────────────────────────────────────────────────────┐${NC}
EOF
        printf "${BLUE}│${NC} ${GREEN}OS:${NC} %-14s ${BLUE}│${NC} ${GREEN}PkgMgr:${NC} %-10s ${BLUE}│${NC} ${GREEN}BlackArch:${NC} %-8s ${BLUE}│${NC}\n" "${os_val}" "${pkg_val}" "${ba_val}"
        printf "${BLUE}│${NC} ${GREEN}Tools:${NC} %-11s ${BLUE}│${NC} ${GREEN}Presets:${NC} %-9s ${BLUE}│${NC} ${GREEN}Deps:${NC} %-13s ${BLUE}│${NC}\n" "${tools_val}" "${presets_val}" "${deps_val}"
        echo -e "${BLUE}└───────────────────────────────────────────────────────────────┘${NC}"
    else
        cat << EOF
             _  __     _ _   _____           _       
            | |/ /__ _| (_) |_   _|__   ___ | |___   
            | ' // _\` | | |   | |/ _ \ / _ \| / __|  
            | . \ (_| | | |   | | (_) | (_) | \__ \  
            |_|\_\__,_|_|_|   |_|\___/ \___/|_|___/  
                   [ OFFENSIVE SECURITY TOOLSET ]    
┌───────────────────────────────────────────────────────────────┐
EOF
        printf "│ OS: %-14s │ PkgMgr: %-10s │ BlackArch: %-8s │\n" "${os_val}" "${pkg_val}" "${ba_val}"
        printf "│ Tools: %-11s │ Presets: %-9s │ Deps: %-13s │\n" "${tools_val}" "${presets_val}" "${deps_val}"
        echo "└───────────────────────────────────────────────────────────────┘"
    fi
}

bbs_box_header() {
    local title="$1"
    local width=63
    local title_len=${#title}
    local pad=$(( (width - title_len) / 2 ))
    (( pad < 0 )) && pad=0
    local left_pad
    left_pad=$(printf '%*s' "${pad}" '')
    local right_pad_len=$(( width - title_len - pad ))
    (( right_pad_len < 0 )) && right_pad_len=0
    local right_pad
    right_pad=$(printf '%*s' "${right_pad_len}" '')
    
    if [[ -t 1 && "${NO_TUI:-false}" != "true" ]]; then
        echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║${YELLOW}${left_pad}${title}${right_pad}${BLUE}║${NC}"
        echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    else
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║${left_pad}${title}${right_pad}║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
    fi
}

bbs_read_key() {
    local prompt="${1:-  Choice: }"
    local key=""
    if [[ -t 0 ]]; then
        read -rsp "${prompt}" -n 1 key
        echo "${key}"
    else
        read -rp "${prompt}" key || true
        echo "${key}"
    fi
}

print_summary() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        echo
        info "=== Dry Run Summary ==="
        info "Dry run complete. No packages were installed."
        type export_report &>/dev/null && export_report || true
        return 0
    fi
    
    local total=${#INSTALL_RESULTS[@]}
    local success_count=0
    local fail_count=0
    local skip_count=0
    
    for result in "${INSTALL_RESULTS[@]}"; do
        case "${result}" in
            SUCCESS:*) ((success_count+=1)) ;;
            FAILED:*) ((fail_count+=1)) ;;
            SKIPPED:*) ((skip_count+=1)) ;;
        esac
    done
    
    echo
    info "=== Installation Summary ==="
    info "Total packages: ${total}"
    success "Successful: ${success_count}"
    [[ ${fail_count} -gt 0 ]] && error "Failed: ${fail_count}"
    [[ ${skip_count} -gt 0 ]] && warn "Skipped: ${skip_count}"
    
    if [[ ${fail_count} -gt 0 ]]; then
        echo
        error "Failed packages:"
        for result in "${INSTALL_RESULTS[@]}"; do
            [[ "${result}" == FAILED:* ]] && error "  ${result#FAILED:}"
        done
        type export_report &>/dev/null && export_report || true
        exit 1
    fi
    
    success "All packages installed successfully!"
    type export_report &>/dev/null && export_report || true
}