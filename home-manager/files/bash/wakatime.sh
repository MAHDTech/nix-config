#!/usr/bin/env bash

##################################################
# Name: wakatime
# Description: Wakatime related functions
##################################################

function checkWakaTime() {

	#local WAKATIME_HOME="${HOME}/.config/wakatime"
	local WAKATIME_HOME="${HOME}"
	local WAKATIME_CONFIG="${WAKATIME_HOME}/.wakatime.cfg"

	if [[ ! -d ${WAKATIME_HOME} ]]; then

		mkdir --parents "${WAKATIME_HOME}"

		writeLog "INFO" "Wakatime home directory created."

	fi

	if [[ -f ${WAKATIME_CONFIG} ]]; then

		writeLog "DEBUG" "Wakatime config is present."

	else

		writeLog "WARN" "No Wakatime configuration is present"

		# https://github.com/wakatime/wakatime-cli/blob/develop/USAGE.md
		cat <<-EOF >>"${WAKATIME_CONFIG}"
			[settings]

			hostname = ${HOSTNAME}

			debug = ${WAKATIME_DEBUG:=false}

			api_url = https://api.wakatime.com/api/v1
			api_key = ${WAKATIME_API_KEY:-MISSING_API_KEY}
			#api_key_vault_cmd = shell command here

			hide_file_names = false
			hide_project_names = false
			hide_branch_names = false
			hide_project_folder = false

			exclude =
			    ^COMMIT_EDITMSG$
			    ^TAG_EDITMSG$
			    ^/var/(?!www/).*
			    ^/etc/

			include =
			    .*

			include_only_with_project_file = false

			exclude_unknown_project = false

			status_bar_enabled = true
			status_bar_coding_activity = true
			status_bar_hide_categories = false

			offline = true
			#proxy = https://user:pass@localhost:8080

			no_ssl_verify = false
			ssl_certs_file =
			timeout = 30
			log_file = ${WAKATIME_HOME}/wakatime.log

			[projectmap]
			#projects/foo = new project name
			#^/home/user/projects/bar(\d+)/ = project{0}

			[project_api_key]
			#projects/foo = your-api-key
			#^/home/user/projects/bar(\d+)/ = your-api-key

			[git]
			submodules_disabled = false

			[git_submodule_projectmap]
			#some/submodule/name = new project name
			#^/home/user/projects/bar(\d+)/ = project{0}

		EOF

		writeLog "INFO" "Default Wakatime config created. Please update the API Key before it will work correctly."

	fi

	return 0

}
