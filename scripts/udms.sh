#!/bin/bash
# udms.sh — First-time bootstrap script for the Ultimate Docker Media Server.
# Run from scripts/ after editing config.env. Creates ~/docker directories,
# installs Docker and Cockpit, seeds initial app configs and shell aliases,
# generates ~/docker/.env, and starts the full Compose stack.

set -e

# Source functions and configurations
source ./functions.sh

# Main function
main() {
    print_intro
    echo
    create_directories
    echo
    install_docker
    echo
    verify_docker
    echo
    install_cockpit
    echo
    set_permissions
    echo
    create_compose_files
    echo
    create_qbittorrent_config
    echo
    create_homepage_config
    echo
    create_docker_gc_exclude
    echo
    create_decypharr_config
    echo
    add_docker_aliases
    echo
    start_containers
    echo
    print_setup_complete
}

main
