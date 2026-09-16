#!/usr/bin/env bash
set -euo pipefail

declare -A TOOL_CATEGORIES
declare -A TOOL_DESCRIPTIONS
declare -A CATEGORY_TOOLS
declare -A TOOL_PKG_MAPPINGS

load_tool_list() {
    if [[ ! -f "${KALI_TOOLS_LIST}" ]]; then
        error "Tool list not found: ${KALI_TOOLS_LIST}"
        exit 1
    fi
    
    local tool category desc debian_pkg arch_pkg fedora_pkg slackware_pkg opensuse_pkg gentoo_pkg alpine_pkg void_pkg deps
    while IFS='|' read -r tool category desc debian_pkg arch_pkg fedora_pkg slackware_pkg opensuse_pkg gentoo_pkg alpine_pkg void_pkg deps; do
        [[ "${tool}" =~ ^#.*$ ]] && continue
        [[ -z "${tool}" ]] && continue
        
        TOOL_CATEGORIES["${tool}"]="${category}"
        TOOL_DESCRIPTIONS["${tool}"]="${desc}"
        CATEGORY_TOOLS["${category}"]+="${tool} "

        [[ -n "${debian_pkg}" ]] && TOOL_PKG_MAPPINGS["debian:${tool}"]="${debian_pkg}"
        [[ -n "${arch_pkg}" ]] && TOOL_PKG_MAPPINGS["arch:${tool}"]="${arch_pkg}"
        [[ -n "${fedora_pkg}" ]] && TOOL_PKG_MAPPINGS["fedora:${tool}"]="${fedora_pkg}"
        [[ -n "${slackware_pkg}" ]] && TOOL_PKG_MAPPINGS["slackware:${tool}"]="${slackware_pkg}"
        [[ -n "${opensuse_pkg}" ]] && TOOL_PKG_MAPPINGS["opensuse:${tool}"]="${opensuse_pkg}"
        [[ -n "${gentoo_pkg}" ]] && TOOL_PKG_MAPPINGS["gentoo:${tool}"]="${gentoo_pkg}"
        [[ -n "${alpine_pkg}" ]] && TOOL_PKG_MAPPINGS["alpine:${tool}"]="${alpine_pkg}"
        [[ -n "${void_pkg}" ]] && TOOL_PKG_MAPPINGS["void:${tool}"]="${void_pkg}"
    done < "${KALI_TOOLS_LIST}"
    
    debug "Loaded ${#TOOL_CATEGORIES[@]} tools across ${#CATEGORY_TOOLS[@]} categories"
}

get_categories() {
    printf '%s\n' "${!CATEGORY_TOOLS[@]}" | sort -u
}

get_tools_in_category() {
    local category="$1"
    echo "${CATEGORY_TOOLS[${category}]:-}"
}

get_tool_category() {
    local tool="$1"
    echo "${TOOL_CATEGORIES[${tool}]:-}"
}

get_tool_description() {
    local tool="$1"
    echo "${TOOL_DESCRIPTIONS[${tool}]:-}"
}

list_all_tools() {
    printf '%s\n' "${!TOOL_CATEGORIES[@]}" | sort
}

validate_tool() {
    local tool="$1"
    [[ -n "${TOOL_CATEGORIES[${tool}]:-}" ]]
}

validate_category() {
    local category="$1"
    [[ -n "${CATEGORY_TOOLS[${category}]:-}" ]]
}

declare -A PRESET_TOOLS
declare -A PRESET_DESCRIPTIONS

init_presets() {
    PRESET_DESCRIPTIONS["top10"]="Top 10 essential Kali security tools"
    PRESET_TOOLS["top10"]="aircrack-ng burpsuite hydra john hashcat metasploit-framework nikto nmap sqlmap wireshark"

    PRESET_DESCRIPTIONS["default"]="Core Kali default suite (35 essential tools)"
    PRESET_TOOLS["default"]="nmap masscan dnsrecon recon-ng theharvester nikto sqlmap burpsuite owasp-zap gobuster dirb wfuzz whatweb wpscan hydra john hashcat medusa ncrack crunch aircrack-ng wifite kismet reaver metasploit-framework exploitdb searchsploit powersploit setoolkit wireshark tcpdump ettercap bettercap socat proxychains"

    PRESET_DESCRIPTIONS["headless"]="CLI-only security tools for servers, VPS, and containers"
    PRESET_TOOLS["headless"]="nmap masscan dnsrecon recon-ng theharvester nikto sqlmap gobuster dirb wfuzz whatweb wpscan hydra john hashcat medusa ncrack crunch cewl aircrack-ng wifite kismet reaver metasploit-framework exploitdb searchsploit tcpdump ettercap bettercap socat proxychains stunnel"

    PRESET_DESCRIPTIONS["web"]="Web application penetration testing suite"
    PRESET_TOOLS["web"]="burpsuite owasp-zap nikto dirb gobuster wfuzz whatweb wpscan joomscan cmsmap"

    PRESET_DESCRIPTIONS["wireless"]="Wireless network auditing and attack tools"
    PRESET_TOOLS["wireless"]="aircrack-ng wifite kismet reaver bully pixiewps wash fern-wifi-cracker mdk3 mdk4"

    PRESET_DESCRIPTIONS["passwords"]="Password cracking, brute-forcing, and wordlists"
    PRESET_TOOLS["passwords"]="john hashcat hydra medusa ncrack crunch cewl cupp"
}

init_presets

get_presets() {
    printf '%s\n' "${!PRESET_TOOLS[@]}" | sort
}

get_preset_description() {
    local preset="$1"
    echo "${PRESET_DESCRIPTIONS[${preset}]:-}"
}

get_tools_in_preset() {
    local preset="$1"
    echo "${PRESET_TOOLS[${preset}]:-}"
}

validate_preset() {
    local preset="$1"
    [[ -n "${PRESET_TOOLS[${preset}]:-}" ]]
}