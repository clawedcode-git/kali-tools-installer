#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

CONTAINER_ENGINE=""
if command -v docker >/dev/null 2>&1; then
    CONTAINER_ENGINE="docker"
elif command -v podman >/dev/null 2>&1; then
    CONTAINER_ENGINE="podman"
fi

print_help() {
    cat << EOF
Usage: $(basename "$0") [DISTRO] [COMMAND...]

Run Kali Tools Installer test suite or arbitrary commands inside containerized Linux distributions.

Distributions:
    arch        Arch Linux (pacman)
    ubuntu      Ubuntu 24.04 LTS (apt)
    debian      Debian 12 Bookworm (apt)
    fedora      Fedora 40 (dnf)
    alpine      Alpine Linux (apk)
    opensuse    openSUSE Tumbleweed (zypper)
    all         Run test suite across all distributions sequentially

Options:
    --help, -h  Show this help

Examples:
    $(basename "$0") arch
    $(basename "$0") debian
    $(basename "$0") all
    $(basename "$0") arch ./install.sh --preset top10 --dry-run
    $(basename "$0") fedora ./install.sh --config config/kali-installer.conf.example --dry-run
EOF
}

get_image_for_distro() {
    local distro="$1"
    case "${distro,,}" in
        arch|archlinux) echo "archlinux:latest" ;;
        ubuntu)         echo "ubuntu:24.04" ;;
        debian)         echo "debian:bookworm" ;;
        fedora)         echo "fedora:40" ;;
        alpine)         echo "alpine:latest" ;;
        opensuse)       echo "opensuse/tumbleweed:latest" ;;
        *)              echo "" ;;
    esac
}

get_setup_cmd_for_distro() {
    local distro="$1"
    case "${distro,,}" in
        arch|archlinux) echo "pacman -Syu --noconfirm --needed bash coreutils grep sed git" ;;
        ubuntu|debian)  echo "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends bash coreutils grep sed git" ;;
        fedora)         echo "dnf install -y bash coreutils grep sed git" ;;
        alpine)         echo "apk add --no-cache bash coreutils grep sed git" ;;
        opensuse)       echo "zypper --non-interactive install -y bash coreutils grep sed git" ;;
        *)              echo "true" ;;
    esac
}

run_on_distro() {
    local distro="$1"
    shift
    local cmd=("$@")
    
    local image
    image=$(get_image_for_distro "${distro}")
    if [[ -z "${image}" ]]; then
        echo -e "${RED}[ERROR] Unknown distribution: ${distro}${NC}" >&2
        return 1
    fi
    
    echo -e "${BLUE}=== Running on ${distro} (${image}) ===${NC}"
    
    local setup_cmd
    setup_cmd=$(get_setup_cmd_for_distro "${distro}")
    
    local exec_cmd
    if [[ ${#cmd[@]} -eq 0 ]]; then
        exec_cmd="bash tests/test_install.sh"
    else
        exec_cmd="${cmd[*]}"
    fi
    
    "${CONTAINER_ENGINE}" run --rm \
        -v "${PROJECT_ROOT}:/workspace:ro" \
        -w /workspace \
        "${image}" \
        bash -c "${setup_cmd} && ${exec_cmd}"
}

main() {
    if [[ $# -eq 0 || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        print_help
        exit 0
    fi
    
    if [[ -z "${CONTAINER_ENGINE}" ]]; then
        echo -e "${RED}[ERROR] Neither docker nor podman was found on PATH.${NC}" >&2
        echo -e "${YELLOW}Please install Docker (https://docs.docker.com/get-docker/) or Podman to use this runner.${NC}" >&2
        exit 1
    fi
    
    local target="$1"
    shift
    
    if [[ "${target,,}" == "all" ]]; then
        local distros=("arch" "ubuntu" "debian" "fedora" "alpine" "opensuse")
        local failed=0
        for d in "${distros[@]}"; do
            if run_on_distro "${d}" "$@"; then
                echo -e "${GREEN}[PASS] ${d} succeeded${NC}\n"
            else
                echo -e "${RED}[FAIL] ${d} failed${NC}\n"
                ((failed+=1))
            fi
        done
        if [[ ${failed} -eq 0 ]]; then
            echo -e "${GREEN}=== ALL MULTI-DISTRO TESTS PASSED ===${NC}"
            exit 0
        else
            echo -e "${RED}=== ${failed} DISTRIBUTION(S) FAILED ===${NC}"
            exit 1
        fi
    else
        run_on_distro "${target}" "$@"
    fi
}

main "$@"
