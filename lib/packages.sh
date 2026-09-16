#!/usr/bin/env bash
set -euo pipefail

declare -A TOOL_CATEGORIES=([_init]="")
declare -A TOOL_DESCRIPTIONS=([_init]="")
declare -A CATEGORY_TOOLS=([_init]="")
declare -A TOOL_PKG_MAPPINGS=([_init]="")
declare -A TOOL_DEPS=([_init]="")

load_tool_list() {
    if [[ ! -f "${KALI_TOOLS_LIST}" ]]; then
        error "Tool list not found: ${KALI_TOOLS_LIST}"
        exit 1
    fi
    
    unset TOOL_CATEGORIES["_init"] 2>/dev/null || true
    unset TOOL_DESCRIPTIONS["_init"] 2>/dev/null || true
    unset CATEGORY_TOOLS["_init"] 2>/dev/null || true
    unset TOOL_PKG_MAPPINGS["_init"] 2>/dev/null || true
    unset TOOL_DEPS["_init"] 2>/dev/null || true
    
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

        deps="${deps:-}"
        deps="${deps#"${deps%%[![:space:]]*}"}"
        deps="${deps%"${deps##*[![:space:]]}"}"
        [[ -n "${deps}" ]] && TOOL_DEPS["${tool}"]="${deps}"
    done < "${KALI_TOOLS_LIST}"
    
    debug "Loaded ${#TOOL_CATEGORIES[@]} tools across ${#CATEGORY_TOOLS[@]} categories"
}

get_categories() {
    printf '%s\n' "${!CATEGORY_TOOLS[@]}" | grep -v '^_init$' | sort -u
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

get_tool_deps() {
    local tool="$1"
    echo "${TOOL_DEPS[${tool}]:-}"
}

get_all_deps_for_tools() {
    local -a tools=("$@")
    local -A seen_deps=()
    local -a result=()
    
    for tool in "${tools[@]}"; do
        local tool_dep_str
        tool_dep_str=$(get_tool_deps "${tool}")
        if [[ -n "${tool_dep_str}" ]]; then
            local -a split_deps=()
            IFS=',' read -ra split_deps <<< "${tool_dep_str}"
            for dep in "${split_deps[@]}"; do
                dep="${dep#"${dep%%[![:space:]]*}"}"
                dep="${dep%"${dep##*[![:space:]]}"}"
                if [[ -n "${dep}" && -z "${seen_deps["${dep}"]:-}" ]]; then
                    seen_deps["${dep}"]="1"
                    result+=("${dep}")
                fi
            done
        fi
    done
    
    if [[ ${#result[@]} -gt 0 ]]; then
        printf '%s\n' "${result[@]}"
    fi
}

resolve_dep_pkg() {
    local dep="$1"
    local family="${2:-${DISTRO_FAMILY:-arch}}"
    
    case "${dep}" in
        python3-pip|pip|pip3)
            case "${family}" in
                arch) echo "python-pip" ;;
                alpine) echo "py3-pip" ;;
                gentoo) echo "dev-python/pip" ;;
                *) echo "python3-pip" ;;
            esac
            ;;
        python3|python)
            case "${family}" in
                arch) echo "python" ;;
                gentoo) echo "dev-lang/python" ;;
                *) echo "python3" ;;
            esac
            ;;
        curl)
            case "${family}" in
                gentoo) echo "net-misc/curl" ;;
                *) echo "curl" ;;
            esac
            ;;
        git)
            case "${family}" in
                gentoo) echo "dev-vcs/git" ;;
                *) echo "git" ;;
            esac
            ;;
        go|golang)
            case "${family}" in
                arch) echo "go" ;;
                debian) echo "golang-go" ;;
                fedora) echo "golang" ;;
                gentoo) echo "dev-lang/go" ;;
                *) echo "go" ;;
            esac
            ;;
        cmake)
            case "${family}" in
                gentoo) echo "dev-build/cmake" ;;
                *) echo "cmake" ;;
            esac
            ;;
        make)
            case "${family}" in
                gentoo) echo "dev-build/make" ;;
                *) echo "make" ;;
            esac
            ;;
        gcc)
            case "${family}" in
                gentoo) echo "sys-devel/gcc" ;;
                *) echo "gcc" ;;
            esac
            ;;
        base-devel|build-essential)
            case "${family}" in
                arch) echo "base-devel" ;;
                debian) echo "build-essential" ;;
                alpine) echo "build-base" ;;
                fedora) echo "gcc,make" ;;
                void) echo "base-devel" ;;
                opensuse) echo "devel_basis" ;;
                gentoo) echo "sys-devel/gcc" ;;
                *) echo "base-devel" ;;
            esac
            ;;
        libpcap)
            case "${family}" in
                arch) echo "libpcap" ;;
                debian) echo "libpcap-dev" ;;
                fedora|void|opensuse) echo "libpcap-devel" ;;
                alpine) echo "libpcap-dev" ;;
                gentoo) echo "net-libs/libpcap" ;;
                *) echo "libpcap" ;;
            esac
            ;;
        ruby)
            case "${family}" in
                gentoo) echo "dev-lang/ruby" ;;
                *) echo "ruby" ;;
            esac
            ;;
        *)
            echo "${dep}"
            ;;
    esac
}

get_build_prerequisites() {
    local method="$1"
    case "${method}" in
        go)
            echo "go git"
            ;;
        pip)
            echo "python3 python3-pip git"
            ;;
        gem)
            echo "ruby git"
            ;;
        make)
            echo "make gcc git base-devel"
            ;;
        cmake)
            echo "cmake make gcc git base-devel"
            ;;
        git)
            echo "git"
            ;;
        *)
            echo ""
            ;;
    esac
}

list_all_tools() {
    printf '%s\n' "${!TOOL_CATEGORIES[@]}" | grep -v '^_init$' | sort
}

validate_tool() {
    local tool="$1"
    [[ "${tool}" != "_init" && -n "${TOOL_CATEGORIES[${tool}]:-}" ]]
}

validate_category() {
    local category="$1"
    [[ "${category}" != "_init" && -n "${CATEGORY_TOOLS[${category}]:-}" ]]
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