#!/usr/bin/env bash
set -euo pipefail

detect_distro() {
    local os_release="/etc/os-release"
    local id=""
    local id_like=""
    
    if [[ ! -f "${os_release}" ]]; then
        error "Cannot detect distribution: ${os_release} not found"
        exit 1
    fi
    
    source "${os_release}"
    id="${ID:-}"
    id_like="${ID_LIKE:-}"
    
    debug "Detected ID: ${id}, ID_LIKE: ${id_like}"
    
    if [[ -n "${FORCE_DISTRO:-}" ]]; then
        id="${FORCE_DISTRO}"
        warn "Forcing distribution: ${id}"
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
}

get_distro_pkg_name() {
    local tool="$1"
    local field=""
    
    case "${DISTRO_FAMILY}" in
        arch) field="arch_pkg" ;;
        debian) field="debian_pkg" ;;
        fedora) field="fedora_pkg" ;;
        slackware) field="slackware_pkg" ;;
        opensuse) field="opensuse_pkg" ;;
        gentoo) field="gentoo_pkg" ;;
        alpine) field="alpine_pkg" ;;
        void) field="void_pkg" ;;
        *) field="debian_pkg" ;;
    esac
    
    local pkg_name
    pkg_name=$(awk -F'|' -v tool="${tool}" -v field="${field}" '
        $1 == tool { 
            split($0, a, "|")
            for (i=1; i<=NF; i++) {
                if (i == 4 && field == "debian_pkg") print a[i]
                if (i == 5 && field == "arch_pkg") print a[i]
                if (i == 6 && field == "fedora_pkg") print a[i]
                if (i == 7 && field == "slackware_pkg") print a[i]
                if (i == 8 && field == "opensuse_pkg") print a[i]
                if (i == 9 && field == "gentoo_pkg") print a[i]
                if (i == 10 && field == "alpine_pkg") print a[i]
                if (i == 11 && field == "void_pkg") print a[i]
            }
        }
    ' "${KALI_TOOLS_LIST}")
    
    echo "${pkg_name}"
}