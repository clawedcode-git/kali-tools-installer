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
    
    local line tool category desc debian_pkg arch_pkg fedora_pkg slackware_pkg opensuse_pkg gentoo_pkg alpine_pkg void_pkg deps
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