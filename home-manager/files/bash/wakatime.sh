#!/usr/bin/env bash

##################################################
# Name: wakatime
# Description: Wakatime related functions
##################################################

function checkWakaTime() {

	local WAKATIME_CONFIG="${HOME}/.wakatime.cfg"
	local WAKATIME_PASS

	if [[ -f "${WAKATIME_CONFIG}" ]];
	then

		if ! grep -q "hide_file_names" "${WAKATIME_CONFIG}" > /dev/null;
		then
			writeLog "WARN" "Please add 'hide_file_names' settings to your wakatime config"
			WAKATIME_PASS="FALSE"
		fi

		if ! grep -q "hide_project_names" "${WAKATIME_CONFIG}" > /dev/null;
		then
			writeLog "WARN" "Please add 'hide_project_names' settings to your wakatime config"
			WAKATIME_PASS="FALSE"
		fi

	else

		writeLog "WARN" "No Wakatime configuration is present"
		cat <<- EOF >> "${WAKATIME_CONFIG}"
		[settings]

		debug = false
		api_key = ${WAKATIME_API_KEY:-MISSING_API_KEY}
		hide_file_names =
		    /Projects/hidden/
		    /Projects/secret/
		    /projects/hidden/
		    /projects/secret/
		hide_project_names =
		    /Projects/hidden/
		    /Projects/secret/
		    /projects/hidden/
		    /projects/secret/
		hide_branch_names = false
		ignore =
		    COMMIT_EDITMSG$
		    PULLREQ_EDITMSG$
		    MERGE_MSG$
		    TAG_EDITMSG$
		exclude =
		    ^COMMIT_EDITMSG$
		    ^TAG_EDITMSG$
		    ^/var/(?!www/).*
		    ^/etc/
		include =
		    .*
		include_only_with_project_file = false
		status_bar_icon = true
		status_bar_enabled = true
		status_bar_hide_categories = false
		status_bar_coding_activity = true
		offline = true
		no_ssl_verify = false
		ssl_certs_file =
		timeout = 30
		hostname = ${HOSTNAME}

		[git]
		
		disable_submodules = false
		
		EOF

		writeLog "INFO" "Default Wakatime config created. Please update the API Key before it will work correctly."

	fi

	if [[ "${WAKATIME_PASS:-TRUE}" == "TRUE" ]];
	then
		return 0
	else
		return 1
	fi

}

