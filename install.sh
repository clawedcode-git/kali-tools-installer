#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT
export PROJECT_ROOT

source "${PROJECT_ROOT}/lib/utils.sh"
source "${PROJECT_ROOT}/lib/distro.sh"
source "${PROJECT_ROOT}/lib/packages.sh"
source "${PROJECT_ROOT}/lib/installer.sh"
source "${PROJECT_ROOT}/lib/menu.sh"

cleanup_terminal() {
    if [[ -t 0 ]]; then
        stty echo 2>/dev/null || true
    fi
}
trap cleanup_terminal EXIT INT TERM

main() {
    load_default_configs "$@"
    parse_args "$@"
    
    if [[ "${SHOW_HELP}" == "true" ]]; then
        print_help
        exit 0
    fi
    
    init_logging
    detect_distro
    load_tool_list
    
    if [[ "${LIST_INSTALLED}" == "true" ]]; then
        list_installed_tools
        exit 0
    fi
    
    if [[ "${PRECHECK}" == "true" ]]; then
        run_precheck
        if [[ "${DRY_RUN}" != "true" ]]; then
            exit 0
        fi
    fi
    
    select_installation_scope
    
    if [[ "${UNINSTALL:-false}" == "true" ]]; then
        confirm_uninstallation
        if [[ "${DRY_RUN}" != "true" ]]; then
            check_root
        fi
        run_uninstallation
        print_uninstall_summary
        exit 0
    fi
    
    confirm_installation
    if [[ "${DRY_RUN}" != "true" ]]; then
        check_root
    fi
    run_installation
    print_summary
}

main "$@"