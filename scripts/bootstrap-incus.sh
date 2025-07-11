#!/usr/bin/env bash

# Name: bootstrap-incus.sh
# Description: Bootstrap Incus nodes based on hostname.


#########################
# Variables
#########################

declare -r INCUS_NODENAME=$(hostname)

#########################
# Functions
#########################

function log() {
    local LEVEL="${1}"
    local MESSAGE="${2}"

    case "${LEVEL^^}" in
        "DEBUG")
            echo -e "\033[34m${MESSAGE}\033[0m"
            ;;
        "INFO")
            echo -e "\033[32m${MESSAGE}\033[0m"
            ;;
        "WARN")
            echo -e "\033[33m${MESSAGE}\033[0m"
            ;;
        "ERROR")
            echo -e "\033[31m${MESSAGE}\033[0m"
            ;;
        *)
            echo -e "${MESSAGE}"
            ;;
    esac
    return 0
}

function incus_check() {
    local INCUS_TOOLS=(
        "incus"
        "incus-agent"
        "incus-bridge"
        "incus-check"
        "incus-config"
        "incus-device"
        "incus-exec"
        "incus-image"
    )

    # Make sure we have the required incus tools available.
    for TOOL in "${INCUS_TOOLS[@]}"; do
        if ! command -v "${TOOL}" &> /dev/null; then
            log "ERROR" "Required Incus tool not found: ${TOOL}"
            exit 1
        fi
    done
    return 0
}

#########################
# Main
#########################

case "${INCUS_NODENAME^^}" in
    
    "HYPERVISOR-1")
        log "INFO" "Configuring Incus cluster bootstrap node: ${INCUS_NODENAME}"
        ;;
    
    "HYPERVISOR-2")
        log "INFO" "Configuring Incus cluster member node: ${INCUS_NODENAME}"
        ;;
    
    "HYPERVISOR-3")
        log "INFO" "Configuring Incus cluster member node: ${INCUS_NODENAME}"
        ;;

    "HYPERVISOR-4")
        log "INFO" "Configuring Incus cluster member node: ${INCUS_NODENAME}"
        ;;

    *)
        log "ERROR" "Unknown Incus node: ${INCUS_NODENAME}"
        exit 1
        ;;
esac
