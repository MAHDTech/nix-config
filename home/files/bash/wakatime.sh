#!/usr/bin/env bash

##################################################
# Name: wakatime
# Description: Wakatime related functions
##################################################

function checkWakaTime() {

	local WAKATIME_DATA="${WAKATIME_DATA:-$HOME/.wakatime}"
	local WAKATIME_CONFIG="${WAKATIME_CONFIG:-$HOME/.wakatime.cfg}"

	if [[ ! -d ${WAKATIME_DATA} ]]; then

		mkdir --parents "${WAKATIME_DATA}"

		writeLog "INFO" "Wakatime data directory created."

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

			exclude_unknown_project = true

			status_bar_enabled = true
			status_bar_coding_activity = true
			status_bar_hide_categories = false

			offline = true
			#proxy = https://user:pass@localhost:8080

			no_ssl_verify = false
			ssl_certs_file =
			timeout = 30
			log_file = ${WAKATIME_DATA}/wakatime.log

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

	# Archive closed Antigravity conversations to keep SQLite cumulative size under wakatime-cli's 256MB budget and 5s timeout
	local OPEN_DBS
	OPEN_DBS="$(readlink /proc/[0-9]*/fd/* 2>/dev/null | grep -F '/conversations/' || true)"

	local CONV_DIR ARCHIVE_DIR db
	for CONV_DIR in "$HOME/.gemini/antigravity-cli/conversations" "$HOME/.gemini/antigravity/conversations"; do
		if [[ -d ${CONV_DIR} ]]; then
			ARCHIVE_DIR="${CONV_DIR}-archive"
			mkdir --parents "${ARCHIVE_DIR}"
			while IFS= read -r -d '' db; do
				# Skip if an uncheckpointed non-empty WAL exists or if the DB is held open by a process
				if [[ -s "${db}-wal" ]] || grep -Fqx "${db}" <<<"${OPEN_DBS}"; then
					continue
				fi
				mv -f "${db}" "${ARCHIVE_DIR}/" 2>/dev/null || true
				[[ -e "${db}-wal" ]] && mv -f "${db}-wal" "${ARCHIVE_DIR}/" 2>/dev/null || true
				[[ -e "${db}-shm" ]] && mv -f "${db}-shm" "${ARCHIVE_DIR}/" 2>/dev/null || true
			done < <(find "${CONV_DIR}" -maxdepth 1 -name "*.db" \( -mmin +360 -o \( -size +15M -mmin +30 \) \) -print0 2>/dev/null)
		fi
	done

	return 0

}
