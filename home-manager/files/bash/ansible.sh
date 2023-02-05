#!/usr/bin/env bash

##################################################
# Name: ansible
# Description: Ansible related functions
##################################################

########################
# Functions
########################

function ansible_cfg_workaround_cleanup() {

	# Clean-up temporary files
	writeLog "INFO" "Removing config ${ANSIBLE_CONFIG_TEMP}"

	rm -f "${ANSIBLE_CONFIG_TEMP}" || {
		writeLog "ERROR" "Failed to remove ${ANSIBLE_CONFIG_TEMP}"
	}

	# Remove stale configs
	writeLog "DEBUG" "Removing stale configs in ${PWD}"
	
	find "${PWD}" -maxdepth 1 -type f -name "ansible-*.cfg" -mmin +1440 -delete || {
		writeLog "ERROR" "Failed to removed stale ansible config"
		return 1
	}

	return 0

}

function ansible_cfg_workaround() {

	# Merges multiple ansible.cfg togethor

	# References:
	# https://github.com/ansible/proposals/issues/35
	# https://gitlab.com/-/snippets/1851171

	# Create a temporary working directory
	ANSIBLE_CONFIG_TEMP=$(mktemp -p "${PWD}" ansible-XXXXXXXXXX.cfg)
	export ANSIBLE_CONFIG_TEMP

	# Define the common places the files are located
	local ANSIBLE_CONFIG_FILES
	ANSIBLE_CONFIG_FILES=(
		"/etc/ansible/ansible.cfg"
		"${HOME}/.ansible.cfg"
		"${PWD}/ansible/ansible.cfg"
		"${PWD}/ansible.cfg"
	)

	# Setup a trap incase the ansible run is cancelled
	setup_trap ansible_cfg_workaround_cleanup SIGINT SIGQUIT SIGABRT SIGKILL SIGTERM

	# Check crudini is available
	checkBin crudini || {
		writeLog "ERROR" "Please install crudini in order to merge Ansible config files"
		return 1
	}

	# Merge all possible ansible configuration files
	local ANSIBLE_CONFIG_FILE
	for ANSIBLE_CONFIG_FILE in "${ANSIBLE_CONFIG_FILES[@]}" ;
	do

		if [[ -f "${ANSIBLE_CONFIG_FILE}" ]];
		then

			writeLog "DEBUG" "Merging Ansible config ${ANSIBLE_CONFIG_FILE} into ${ANSIBLE_CONFIG_TEMP}"

			crudini --merge "${ANSIBLE_CONFIG_TEMP}" < "${ANSIBLE_CONFIG_FILE}"

		fi

	done

	if [[ "${ANSIBLE_CONFIG:-EMPTY}" != "EMPTY" ]];
	then

		crudini --merge "${ANSIBLE_CONFIG_TEMP}" < "${ANSIBLE_CONFIG}"

	fi

	writeLog "DEBUG" "Executing Ansible command"
	ANSIBLE_CONFIG="${ANSIBLE_CONFIG_TEMP}" command "$1" "${@:2}"

	# Save exit status
	ANSIBLE_EXIT_STATUS="$?"

	if [[ "${DEBUG:-FALSE}" == "TRUE" ]];
	then
		echo -e "\n"
		echo -e "#########################"
		echo -e "Ansible merged configuration"
		echo -e "#########################"
		cat "${ANSIBLE_CONFIG_TEMP}"
		echo -e "\n"
	fi

	# Manually run cleanup
	ansible_cfg_workaround_cleanup

	# Return playbook exit code
	return "${ANSIBLE_EXIT_STATUS}"

}

########################
# Aliases
########################

alias ansible="ansible_cfg_workaround ansible"
alias ansible-config="ansible_cfg_workaround ansible-config"
alias ansible-console="ansible_cfg_workaround ansible-console"
alias ansible-galaxy="ansible_cfg_workaround ansible-galaxy"
alias ansible-inventory="ansible_cfg_workaround ansible-inventory"
alias ansible-playbook="ansible_cfg_workaround ansible-playbook"
alias ansible-pull="ansible_cfg_workaround ansible-pull"
alias ansible-vault="ansible_cfg_workaround ansible-vault"

