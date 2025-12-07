#!/usr/bin/env bash

clear
set -euo pipefail

# Check for expect (required for password auth)
if ! command -v expect >/dev/null 2>&1; then
	echo "Error: 'expect' is required but not found. Install it via 'nix-env -iA nixpkgs.expect' or run this script with 'nix-shell -p expect --run \"$0\"'."
	exit 1
fi

# AHV variables
AHV_HOSTS_FILE=$(dirname "${BASH_SOURCE[0]}")/nce-hosts-ahv.txt
declare -r AHV_USERNAME="nutanix"
declare -r AHV_PASSWORD_DEFAULT="nutanix/4u"
declare -a AHV_USERS=("root" "nutanix" "admin")
declare -A AHV_PASSWORDS # USER => PASSWORD
declare -a AHV_SUCCESSFUL_HOSTS=()
declare -a AHV_FAILED_HOSTS=()

# CVM variables
CVM_HOSTS_FILE=$(dirname "${BASH_SOURCE[0]}")/nce-hosts-cvm.txt
declare -r CVM_USERNAME="nutanix"
declare -r CVM_PASSWORD_DEFAULT="nutanix/4u"
declare -a CVM_USERS=("root" "nutanix" "admin")
declare -A CVM_PASSWORDS # USER => PASSWORD
declare -a CVM_SUCCESSFUL_HOSTS=()
declare -a CVM_FAILED_HOSTS=()

# Safety checks
[[ ! -f $AHV_HOSTS_FILE ]] && {
	echo "Error: $AHV_HOSTS_FILE not found!"
	exit 1
}
[[ ! -f $CVM_HOSTS_FILE ]] && {
	echo "Error: $CVM_HOSTS_FILE not found!"
	exit 1
}

echo "Starting password update on Nutanix hosts..."

# Prompt for AHV passwords
echo
echo "Gathering AHV passwords..."
for user in "${AHV_USERS[@]}"; do
	read -rsp "Enter new password for '$user' (same across all AHV hosts): " newpass </dev/tty
	echo
	[[ -z $newpass ]] && {
		echo "Password cannot be empty. Exiting."
		exit 1
	}
	# shellcheck disable=SC2034
	AHV_PASSWORDS[$user]="$newpass"
done

echo

# Prompt for CVM passwords
echo
echo "Gathering CVM passwords..."
for user in "${CVM_USERS[@]}"; do
	read -rsp "Enter new password for '$user' (same across all CVM hosts): " newpass </dev/tty
	echo
	[[ -z $newpass ]] && {
		echo "Password cannot be empty. Exiting."
		exit 1
	}
	# shellcheck disable=SC2034
	CVM_PASSWORDS[$user]="$newpass"
done

echo

# Function to test connection with given username and password or key
test_connection() {
	local host="$1" username="$2" pass="$3" preferred="${4:-password}"
	local options="-o PreferredAuthentications=$preferred -o PubkeyAuthentication=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o ControlMaster=no"
	if [ "$preferred" = "publickey" ]; then
		options="$options -o PasswordAuthentication=no"
	fi
	expect -c "
		spawn ssh $options $username@$host true
		if [ \"$preferred\" = \"password\" ]; then
			expect \"password:\"
			send \"$pass\\r\"
			expect eof
		else
			expect {
				\"password:\" { exit 1 }
				eof { exit 0 }
			}
		fi
	" >/dev/null 2>&1
}

# Function to update password via expect
update_password() {
	local host="$1" user="$2" pass="$3" connect_username="$4" connect_pass="$5" preferred="${6:-password,publickey}"
	expect -c "
		spawn ssh \
			-o PreferredAuthentications=$preferred \
			-o PubkeyAuthentication=yes \
			-o ConnectTimeout=10 \
			-o StrictHostKeyChecking=no \
			-o ConnectionAttempts=3 \
			-o ControlMaster=no \
			$connect_username@$host bash
		expect {
			\"password:\" {
				if [ \"$connect_pass\" != \"key\" ]; then
					send \"$connect_pass\\r\"
					expect -re {\\[.*\\].*\\\$ } { }
				else
					exit 1
				fi
			}
			-re {\\[.*\\].*\\\$ } {
			}
		}
		send \"sudo echo '$user:$pass' | chpasswd\\r\"
		if [ \"$connect_pass\" != \"key\" ]; then
			expect \"password for $connect_username:\"
			send \"$connect_pass\\r\"
			expect -re {\\[.*\\].*\\\$ } { }
		else
			expect {
				\"password for $connect_username:\" { exit 1 }
				-re {\\[.*\\].*\\\$ } { }
			}
		fi
		send \"exit\\r\"
		expect eof
	" >/dev/null 2>&1
}

# Function to verify password via expect
verify_password() {
	local host="$1" user="$2" pass="$3"
	expect -c "
		spawn ssh -o PreferredAuthentications=password,publickey -o PubkeyAuthentication=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o ControlMaster=no $user@$host true
		expect \"password:\"
		send \"$pass\\r\"
		expect eof
	" >/dev/null 2>&1
}

# Common function to process hosts
process_hosts() {
	local hosts_file="$1" username="$2" users_ref="$3" passwords_ref="$4" successful_hosts_ref="$5" failed_hosts_ref="$6" default_pass="$7"
	local -n users=$users_ref passwords=$passwords_ref successful_hosts=$successful_hosts_ref failed_hosts=$failed_hosts_ref

	echo "Processing hosts from $hosts_file..."

	while IFS= read -r machine || [[ -n $machine ]]; do
		[[ -z $machine || $machine =~ ^[[:space:]]*# ]] && continue

		echo "===== Processing host: $machine ====="

		local connect_username="$username"
		# Determine working authentication
		if test_connection "$machine" "$username" "$default_pass" "password"; then
			connect_pass="$default_pass"
			echo "Connected with default password."
		elif test_connection "$machine" "$username" "${passwords[$username]}" "password"; then
			connect_pass="${passwords[$username]}"
			echo "Connected with new password."
		elif test_connection "$machine" "$username" "" "publickey"; then
			connect_username="$username"
			connect_pass="key"
			echo "Connected with SSH key."
		else
			echo "Cannot connect. Skipping."
			failed_hosts+=("$machine")
			continue
		fi

		for user in "${users[@]}"; do
			newpass="${passwords[$user]}"
			echo "Updating password for $user..."
			preferred_auth="password,publickey"
			if [ "$connect_pass" = "key" ]; then
				preferred_auth="publickey"
			fi
			if update_password "$machine" "$user" "$newpass" "$connect_username" "$connect_pass" "$preferred_auth"; then
				echo "Success: Password changed for $user"
				if verify_password "$machine" "$user" "$newpass"; then
					echo "Verification successful"
				else
					echo "Verification failed"
				fi
			else
				echo "Failed to update password for $user"
			fi
			unset newpass
		done

		unset connect_pass
		successful_hosts+=("$machine")
		echo
	done <"$hosts_file"

	echo "Finished processing from $hosts_file."
}

# Process AHV hosts
process_hosts "$AHV_HOSTS_FILE" "$AHV_USERNAME" "AHV_USERS" "AHV_PASSWORDS" "AHV_SUCCESSFUL_HOSTS" "AHV_FAILED_HOSTS" "$AHV_PASSWORD_DEFAULT"

# Process CVM hosts
process_hosts "$CVM_HOSTS_FILE" "$CVM_USERNAME" "CVM_USERS" "CVM_PASSWORDS" "CVM_SUCCESSFUL_HOSTS" "CVM_FAILED_HOSTS" "$CVM_PASSWORD_DEFAULT"

echo "All done!"
echo
echo "AHV Nodes OK: ${AHV_SUCCESSFUL_HOSTS[*]}"
echo "AHV Nodes failed: ${AHV_FAILED_HOSTS[*]}"
echo "CVM Nodes OK: ${CVM_SUCCESSFUL_HOSTS[*]}"
echo "CVM Nodes failed: ${CVM_FAILED_HOSTS[*]}"
