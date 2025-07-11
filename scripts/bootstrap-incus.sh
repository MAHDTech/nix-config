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
    for TOOL in "${INCUS_TOOLS[@]}";
    do
        if ! command -v "${TOOL}" &> /dev/null;
        then
            log "ERROR" "Required Incus tool not found: ${TOOL}"
            return 1
        fi
    done

    return 0
}

function incus_bootstrap() {
    local NODE=$1
    local TYPE=$2

    case "${TYPE^^}" in

        "BOOTSTRAP")
            log "INFO" "Bootstrapping cluster on ${NODE}"

            # Apply preseed if not initialized
            incus cluster list &> /dev/null || incus admin init --preseed

            # Generate join token
            TOKEN=$(incus cluster add-token cluster-join 2>/dev/null)

            if [[ -n "${TOKEN}" ]];
            then
                log "INFO" "Join token generated: ${TOKEN}"
                echo "Save this token for joiners: ${TOKEN}"
            else
                log "WARN" "Token already exists or cluster initialized"
                return 1
            fi
            
        ;;

        "JOIN")
            log "INFO" "Joining cluster on $NODE"

            if [[ -z "$JOIN_TOKEN" ]];
            then
                read -p "Enter join token: " JOIN_TOKEN
            fi
            
            incus admin init --cluster-address=https://10.10.200.11:8443 --cluster-join-token="$JOIN_TOKEN"
            
        ;;
    esac
    
    return 0
}

function configure_ui() {
    log "INFO" "Configuring Web UI"
    
    incus config get core.https_address | grep -q :8443 || incus config set core.https_address :8443
    
    if [[ ! -d /var/lib/incus/ui ]];
    then
        log "ERROR" "UI files missing - install incus-ui-canonical"
        return 1
    fi
    
    grep -q INCUS_UI /etc/environment || echo 'INCUS_UI=/var/lib/incus/ui' >> /etc/environment
    
    # Restart incus
    systemctl restart incus || {
        log "ERROR" "Failed to restart incus"
        return 1
    }

    return 0
}

#########################
# Main
#########################

incus_check || {
    log "ERROR" "Incus tools not found"
    exit 1
}

case "${INCUS_NODENAME^^}" in
    
    "HYPERVISOR-1")
        log "INFO" "Configuring Incus cluster bootstrap node: ${INCUS_NODENAME}"

        incus_bootstrap "$INCUS_NODENAME" "BOOTSTRAP" || {
            log "ERROR" "Failed to bootstrap cluster"
            exit 1
        }

    ;;
    
    "HYPERVISOR-2")
        log "INFO" "Configuring Incus cluster member node: ${INCUS_NODENAME}"

        incus_bootstrap "$INCUS_NODENAME" "JOIN" || {
            log "ERROR" "Failed to join cluster"
            exit 1
        }
    
    ;;
    
    "HYPERVISOR-3")
        log "INFO" "Configuring Incus cluster member node: ${INCUS_NODENAME}"

        incus_bootstrap "$INCUS_NODENAME" "JOIN" || {
            log "ERROR" "Failed to join cluster"
            exit 1
        }

    ;;

    "HYPERVISOR-4")
        log "INFO" "Configuring Incus cluster member node: ${INCUS_NODENAME}"

        incus_bootstrap "$INCUS_NODENAME" "JOIN" || {
            log "ERROR" "Failed to join cluster"
            exit 1
        }

    ;;

    *)
        log "ERROR" "Unknown Incus node: ${INCUS_NODENAME}"
        exit 1

    ;;
esac


configure_ui || {
    log "ERROR" "Failed to configure Web UI"
    exit 1
}

log "INFO" "Verifying firewall for port 8443"
nft list ruleset | grep -q 8443 || log "WARN" "Don't forget to add a firewwall rule for TCP 8443"
