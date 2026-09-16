#!/usr/bin/env bash
set -euo pipefail

detect_distro() {
    local os_release="${OS_RELEASE_FILE:-/etc/os-release}"
    local id=""
    local id_like=""
    
    if [[ -n "${FORCE_DISTRO:-}" ]]; then
        id="${FORCE_DISTRO,,}"
        DISTRO_NAME="${id}"
        warn "Forcing distribution: ${id}"
    elif [[ -f "${os_release}" ]]; then
        source "${os_release}" 2>/dev/null || true
        id="${ID:-}"
        id="${id,,}"
        id_like="${ID_LIKE:-}"
        id_like="${id_like,,}"
        DISTRO_NAME="${id}"
        debug "Detected ID: ${id}, ID_LIKE: ${id_like}"
    else
        error "Cannot detect distribution: ${os_release} not found"
        error "Use --distro to force a supported distribution"
        exit 1
    fi
    
    case "${id}" in
        arch|cachyos|manjaro|endeavouros|garuda|artix)
            DISTRO="arch"
            DISTRO_FAMILY="arch"
            PACKAGE_MANAGER="pacman"
            ;;
        debian|ubuntu|kali|linuxmint|pop|elementary|zorin)
            DISTRO="debian"
            DISTRO_FAMILY="debian"
            PACKAGE_MANAGER="apt"
            ;;
        fedora|rhel|centos|rocky|almalinux|nobara)
            DISTRO="fedora"
            DISTRO_FAMILY="fedora"
            PACKAGE_MANAGER="dnf"
            ;;
        opensuse*|sles)
            DISTRO="opensuse"
            DISTRO_FAMILY="opensuse"
            PACKAGE_MANAGER="zypper"
            ;;
        slackware)
            DISTRO="slackware"
            DISTRO_FAMILY="slackware"
            PACKAGE_MANAGER="slackpkg"
            ;;
        gentoo)
            DISTRO="gentoo"
            DISTRO_FAMILY="gentoo"
            PACKAGE_MANAGER="emerge"
            ;;
        alpine)
            DISTRO="alpine"
            DISTRO_FAMILY="alpine"
            PACKAGE_MANAGER="apk"
            ;;
        void)
            DISTRO="void"
            DISTRO_FAMILY="void"
            PACKAGE_MANAGER="xbps"
            ;;
        *)
            if [[ "${id_like}" =~ arch ]]; then
                DISTRO="arch"
                DISTRO_FAMILY="arch"
                PACKAGE_MANAGER="pacman"
            elif [[ "${id_like}" =~ debian|ubuntu ]]; then
                DISTRO="debian"
                DISTRO_FAMILY="debian"
                PACKAGE_MANAGER="apt"
            elif [[ "${id_like}" =~ fedora|rhel ]]; then
                DISTRO="fedora"
                DISTRO_FAMILY="fedora"
                PACKAGE_MANAGER="dnf"
            else
                error "Unsupported distribution: ${id} (ID_LIKE: ${id_like})"
                error "Use --distro to force a supported distribution"
                exit 1
            fi
            ;;
    esac
    
    info "Detected distribution: ${DISTRO} (family: ${DISTRO_FAMILY})"
    info "Package manager: ${PACKAGE_MANAGER}"
    export DISTRO DISTRO_FAMILY PACKAGE_MANAGER DISTRO_NAME
}

get_distro_pkg_name() {
    local tool="$1"
    tool="${tool#"${tool%%[![:space:]]*}"}"
    tool="${tool%"${tool##*[![:space:]]}"}"
    local family="${DISTRO_FAMILY:-debian}"
    
    if [[ ${#TOOL_PKG_MAPPINGS[@]} -eq 0 && -f "${KALI_TOOLS_LIST:-}" ]]; then
        load_tool_list >/dev/null 2>&1 || true
    fi
    
    echo "${TOOL_PKG_MAPPINGS["${family}:${tool}"]:-}"
}