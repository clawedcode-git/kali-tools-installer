#!/usr/bin/env bash
set -euo pipefail

declare -A TOOL_CATEGORIES
declare -A TOOL_DESCRIPTIONS
declare -A CATEGORY_TOOLS

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
    done < "${KALI_TOOLS_LIST}"
    
    debug "Loaded ${#TOOL_CATEGORIES[@]} tools across $(echo "${!CATEGORY_TOOLS[@]}" | wc -w) categories"
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