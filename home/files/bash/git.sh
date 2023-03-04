#!/usr/bin/env bash

##################################################
# Name: git
# Description: Contains the git related functions
##################################################

function quoteParams() {

	# Takes an array and quotes any strings with spaces.
	# The "PARAMS" array can then be used.

	local PATTERN=" |'"
	unset PARAMS
	declare -ga PARAMS=("${@}")

	# Loop over all the provided params
	for INDEX in "${!PARAMS[@]}"; do

		# If the git param has spaces, quote it
		if [[ ${PARAMS[$INDEX]} =~ ${PATTERN} ]]; then

			writeLog "DEBUG" "Params before: ${PARAMS[$INDEX]}"

			# Quote the string with spaces
			#PARAMS[$INDEX]="\"${PARAMS[$INDEX]}\"" # Adds quotes to git log :(
			#PARAMS[$INDEX]=""${PARAMS[$INDEX]}"" # Adds quotes to git log :(
			PARAMS[$INDEX]="${PARAMS[$INDEX]}"

			writeLog "DEBUG" "Params after: ${PARAMS[$INDEX]}"

		fi

	done

	return 0

}

function DISABLED_dotfiles() {

	# Allows the use of the 'dotfiles' command
	# Remember: https://lwn.net/Articles/701009/

	pushd "${HOME}" >/dev/null || {
		writeLog "ERROR" "Failed to pushd to home"
		return 1
	}

	local LOCATION_DOTFILES
	local LOCATION_GIT
	local GIT_COMMAND="${1}"

	declare -a GIT_PARAMS=("${@:2}")

	LOCATION_DOTFILES="${HOME}/.dotfiles"
	LOCATION_GIT="$(which git)"

	if [[ ! -f ${LOCATION_GIT} ]]; then
		writeLog "ERROR" "Please ensure git is installed and available in the PATH"
		return 1
	fi

	if [[ ${GIT_COMMAND:-EMPTY} == "EMPTY" ]]; then

		"${LOCATION_GIT}" \
			--help ||
			return 1

	elif [[ ${#GIT_PARAMS[@]} -eq 0 ]]; then

		"${LOCATION_GIT}" \
			--git-dir="${LOCATION_DOTFILES}" \
			--work-tree "${HOME}" \
			"${GIT_COMMAND}" ||
			return 1

	else

		quoteParams "${GIT_PARAMS[@]}" || {
			writeLog "ERROR" "Failed to quote parameters"
			return 1
		}

		"${LOCATION_GIT}" \
			--git-dir="${LOCATION_DOTFILES}" \
			--work-tree "${HOME}" \
			"${GIT_COMMAND}" \
			"${PARAMS[@]}" ||
			return 1

	fi

	popd >/dev/null || {
		writeLog "ERROR" "Failed to popd"
		return 1
	}

	return 0

}

function DISABLED_dotfiles_update() {

	# Updates the dotfiles submodules

	writeLog "INFO" "Updating dotfiles submodules"

	dotfiles submodule update --init --recursive || {
		writeLog "ERROR" "Failed to init dotfiles submodules"
		return 1
	}

	dotfiles submodule update --remote --merge --recursive || {
		writeLog "ERROR" "Failed to update dotfiles submodules"
		return 1
	}

	return 0

}

function DISABLE_dotfiles_remind() {

	# Reminds you to stage and commit the changes in your dotfiles

	if ! dotfiles diff --quiet --exit-code; then

		writeLog "WARN" "You have unstaged changes in your dotfiles!"
		return 1

	elif ! dotfiles diff --quiet --exit-code --cached; then

		writeLog "WARN" "You have uncommitted changes in your dotfiles!"
		return 1

	else

		writeLog "INFO" "No unstaged changes in your dotfiles"
		return 0

	fi

}

function git_squash_branch() {

	# Squash the current branch into 1 commit

	local BRANCH="$1"
	local DEFAULT="$2"
	local PATTERN=" |'"
	declare -a GIT_PARAMS=("${@:3}")

	DEFAULT="${DEFAULT:=trunk}"

	if [ "${BRANCH:-EMPTY}" == "EMPTY" ]; then
		writeLog "ERROR" 'Please provide a branch to squash as $1'
		return 1
	fi

	# Returns a global "PARAMS" array
	quoteParams "${GIT_PARAMS[@]}" || {
		writeLog "ERROR" "Failed to quote params"
		return 1
	}

	git checkout "${DEFAULT}"

	git checkout -b "${BRANCH}-temp" || {
		writeLog "ERROR" "Failed to checkout temporary git branch ${BRANCH}-temp"
		return 1
	}

	git merge --squash "${BRANCH}" || {
		writeLog "ERROR" "Failed to squash changes into temporary branch ${BRANCH}-temp"
		return 1
	}

	# shellcheck disable=2086
	git commit --no-verify -am "Squashed branch" "${PARAMS[@]}" || {
		writeLog "ERROR" "Failed to commit changes"
		return 1
	}

	git branch -m "${BRANCH}" "${BRANCH}-unsquashed" || {
		writeLog "ERROR" "Failed to rename unsquashed branch"
		return 1
	}

	git branch -m "${BRANCH}-temp" "${BRANCH}" || {
		writeLog "ERROR" "Failed to rename squashed branch"
		return 1
	}

	#git branch -D "${BRANCH}-unsquashed"

	return 0

}

function git_remove_submodule() {

	# I can never remember the steps so I put them here :/

	local GIT_SUBMODULE_PATH="$1"

	writeLog "INFO" "Remove the section from .gitmodules"
	vim ".gitmodules"
	read -p "Press [Enter] to continue....."

	writeLog "INFO" "Stage the changes to .gitmodules"
	git add .gitmodules ||
		{
			writeLog "ERROR" "Failed to stage .gitmodules"
			return 1
		}
	read -p "Press [Enter] to continue....."

	writeLog "INFO" "Remove the section from .git/config"
	vim ".git/config"
	read -p "Press [Enter] to continue....."

	writeLog "INFO" "Remove the path from git cache"

	if [ "${GIT_SUBMODULE_PATH:-EMPTY}" == "EMPTY" ]; then
		read -p "Enter the git submodule folder name: " -r GIT_SUBMODULE_PATH
		echo -e "\n"
	fi

	if [ ! -d "${GIT_SUBMODULE_PATH}" ]; then
		writeLog "WARN" "There is no existing folder ${GIT_SUBMODULE_PATH}"
	fi

	read -p "Are you sure you want to remove ${GIT_SUBMODULE_PATH} from the git cache? Y/N: " -n 1 -r CHOICE
	echo -e "\n"

	if [[ ${CHOICE} =~ ^[Yy] ]]; then

		git rm -r --cached "${GIT_SUBMODULE_PATH}" ||
			{
				writeLog "ERROR" "Failed to remove submodule from git cache"
				return 1
			}

		rm -rf ".git/modules/$GIT_SUBMODULE_PATH" ||
			{
				writeLog "ERROR" "Failed to remove the git submodule from git tree"
				return 1
			}

		writeLog "INFO" "Staging changes"

		git add --all ||
			{
				writeLog "ERROR" "Failed to stage changes"
				return 1
			}

		writeLog "INFO" "Committing changes"

		git commit --no-gpg-sign --no-verify -am "Removed submodule" ||
			{
				writeLog "ERROR" "Failed to commit changes"
				return 1
			}

		writeLog "INFO" "Removing untracked files"

		rm -rf "${GIT_SUBMODULE_PATH}" ||
			{
				writeLog "ERROR" "Failed to remove git submodule files"
				return 1
			}

	else

		writeLog "WARN" "Script cancelled..."
		return 1

	fi

	return 0

}

function git_prune_large_file() {

	if [[ "${1-}" ]]; then
		local FILENAME="${1}"
	else
		writeLog "ERROR" 'Please provide the large file path as $1. This should be the relative filename based on the git dir context.'
		return 1
	fi

	git filter-branch \
		-d .git-rewrite \
		--force \
		--prune-empty \
		--index-filter \
		"git rm --cached -f --ignore-unmatch ${FILENAME}" \
		--tag-name-filter cat -- --all || {
		writeLog "ERROR" "Failed to prune large file ${FILENAME}"
		return 1
	}

	return 0

}

function git_prune_all() {

	# Deletes all branches and tags not found in origin

	writeLog "INFO" "Pruning local branches and tags not found on remote"

	git fetch \
		--all \
		--prune \
		--tags \
		--prune-tags \
		--verbose ||
		{
			writeLog "ERROR" "Failed to prune all local branches and tags"
			return 1
		}

	return 0

}

function git_prune_merged() {

	# Prunes local branches that have already been merged into the current branch.
	# The intention is to checkout master, and then run this post-merge
	# Any protected branches need to be added to the array below

	writeLog "WARN" "TODO: NOT FINISHED YET"
	return 0

	local TEMPFILE
	local BRANCHES_MERGED
	local -a BRANCHES_PROTECTED=(
		master
		main
		trunk
		environment/production
		environment/staging
		environment/development
	)
	local -i BRANCHES_TOTAL
	local -i BRANCHES_COUNT

	writeLog "INFO" "Listing all branches that have been merged into current branch"

	TEMPFILE=$(mktemp)

	BRANCHES_MERGED=$(git branch --list --merged)
	BRANCHES_TOTAL="${#BRANCHES_PROTECTED[*]}"

	echo "${BRANCHES_MERGED}" | for BRANCH in "${BRANCHES_PROTECTED[@]}"; do

		BRANCHES_COUNT=$(("${BRANCHES_COUNT:-0}" + 1))

		if [[ ${BRANCHES_COUNT} -eq ${BRANCHES_TOTAL} ]]; then

			grep -v "${BRANCH}"

		else

			grep -v "${BRANCH}" \|

		fi

	done >"${TEMPFILE}"

	vi "${TEMPFILE}" &&
		xargs git branch -d <"${TEMPFILE}"

	rm -f "${TEMPFILE}"

	return 0

}

function git_pull_all() {

	# Pulls every branch from origin using the same name as the local branch

	writeLog "WARN" "TODO: NOT FINISHED YET"
	return 0

	git branch -r | grep -v '\->' |
		while read -r REMOTE; do

			writeLog "INFO" "Tracking ${REMOTE#origin/} against ${REMOTE}"
			echo git branch --track "${REMOTE#origin/}" "${REMOTE}"

		done

	git fetch --all ||
		{
			writeLog "ERR" "Failed to git fetch all branches"
			return 1
		}

	git pull --all ||
		{
			writeLog "ERRO" "Failed to git pull all branches"
			return 1
		}

	return 0

}

function git_command_dir() {

	# Returns the git directory

	git rev-parse --git-dir >/dev/null 2>&1

}

function git_command_status() {

	# Returns 0 when there is nothing to commit

	git status 2>/dev/null | grep "nothing to commit" >/dev/null 2>&1

}

function git_status() {

	# Shows git status in PS1
	# Useful characters: 𝘟 ✗ Ӽ 𝘟 𝞦 ✔ ✓ ▲ ➜

	if git_command_dir; then

		if ! git_command_status; then

			# shellcheck disable=SC2154
			echo "${fgRed}𝞦${fgReset}"
			return 0

		elif git_command_status; then

			# shellcheck disable=SC2154
			echo "${fgGreen}✔${fgReset}"
			return 0

		fi

	else

		# shellcheck disable=SC2154
		echo "${fgBlue}➜${fgReset}"
		return 0

	fi

}

function git_branch() {

	# Shows git branch in PS1

	local GIT_BRANCH

	GIT_BRANCH=$(
		git branch --no-color 2>/dev/null |
			sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
	)

	echo -n "${GIT_BRANCH:=none}"

}

function git_reset_branch() {

	# Resets the branches history to a single commit

	local BRANCH="${1}"
	local BRANCH_ERASE="FALSE"
	local BRANCH_DEFAULT="trunk"
	declare -a GIT_PARAMS=("${@:2}")

	if [[ ${BRANCH:-EMPTY} == "EMPTY" ]]; then

		BRANCH="$(git rev-parse --abbrev-ref HEAD)"
		writeLog "INFO" "Resetting current branch ${BRANCH}"

	elif [[ ${BRANCH^^} == "ALL" ]]; then

		writeLog "INFO" "Erasing ALL branch history and re-initializing repository"

		# Trigger deletion of ALL branches
		BRANCH_ERASE="TRUE"
		BRANCH="${BRANCH_DEFAULT}"

	elif [[ ${BRANCH} =~ ^-- ]]; then

		writeLog "INFO" 'Please provide the branch name as $1 and not extra args.'
		return 1

	else

		writeLog "INFO" "Resetting branch history for ${BRANCH}"

	fi

	# Returns a global "PARAMS" array
	quoteParams "${GIT_PARAMS[@]}" || {
		writeLog "ERROR" "Failed to quote params"
		return 1
	}

	git checkout --orphan git_reset ||
		{
			writeLog "ERROR" "Failed to checkout new branch 'git_reset'"
			return 1
		}

	git add --all ||
		{
			writeLog "ERROR" "Failed to stage files"
			return 1
		}

	# Commit all the files into the git_reset branch
	writeLog "INFO" "Initialize new ${BRANCH} branch"

	# shellcheck disable=2086
	git commit --no-verify --message "Initialize ${BRANCH} branch" "${PARAMS[@]}" ||
		{
			writeLog "ERROR" "Failed to commit files"
			return 1
		}

	# Delete the prior branch
	git branch --delete --force "${BRANCH}" ||
		{
			writeLog "ERROR" "Failed to delete branch ${BRANCH}"
			return 1
		}

	# Rename current branch to the prior branch
	git branch --move "${BRANCH}" ||
		{
			writeLog "ERROR" "Failed to rename branch ${BRANCH}"
			return 1
		}

	if [ "${BRANCH_ERASE^^}" == "TRUE" ]; then

		writeLog "INFO" "Removing old branches"

		for OTHER_BRANCH in $(git branch | grep -v "${BRANCH}"); do

			writeLog "INFO" "Removing branch ${OTHER_BRANCH}"
			git branch --delete --force "${OTHER_BRANCH}" ||
				{
					writeLog "ERROR" "Failed to remove branch ${OTHER_BRANCH}"
					return 1
				}

		done

	fi

	# Force push to origin
	git push --force origin "${BRANCH}" ||
		{
			writeLog "ERROR" "Failed to push branch ${BRANCH} to origin"
			return 1
		}

	# Remove old files
	git gc --aggressive --prune=all ||
		{
			writeLog "ERROR" "Failed to run git garbage collection"
			return 1
		}

	return 0

}

function git_reset_tags() {

	# Deletes all the tags

	writeLog "INFO" "Deleting all tags"

	#git tag -l | xargs -n 1 git push --delete origin

	writeLog "INFO" "Syncing local and remote tags"
	git fetch --tags ||
		{
			writeLog "ERROR" "Failed to fetch remote tags"
			return 1
		}

	writeLog "INFO" "Deleting all local tags"
	git tag --list | xargs -n 1 git tag --delete ||
		{
			writeLog "ERROR" "Failed to delete local git tags"
			return 1
		}

	writeLog "INFO" "Fetching all remote tags"
	git fetch --tags ||
		{
			writeLog "ERROR" "Failed to fetch remote tags"
			return 1
		}

	writeLog "INFO" "Deleting all remote tags"
	git tag --list | xargs -n 1 git push --delete origin ||
		{
			writeLog "ERROR" "Failed to delete remote tags"
			return 1
		}

	writeLog "INFO" "Deleting all local tags"
	git tag --list | xargs -n 1 git tag --delete ||
		{
			writeLog "ERROR" "Failed to delete local git tags"
			return 1
		}

	return 0

}

function git_checkout() {

	# Checks out a new branch for work to begin
	# I can never remember the syntax so I just put it here.

	local BRANCH="${1}"

	if [ "${BRANCH:-EMPTY}" == "EMPTY" ]; then
		writeLog "ERROR" "mate, I need a branch name!"
		return 1
	fi

	writeLog "INFO" "Checking out a new branch ${BRANCH} and setting it to track origin/${BRANCH}"

	git pull --all ||
		{
			writeLog "ERROR" "Failed to update the repo"
			return 1
		}

	git checkout -b "${BRANCH}" ||
		{
			writeLog "ERROR" "Failed to checkout a new branch ${BRANCH}"
			return 1
		}

	git push --set-upstream --verbose ||
		{
			writeLog "ERROR" "Failed to set upstream on local branch ${BRANCH} to origin/${BRANCH}"
			return 1
		}

	writeLog "INFO" "Time to GitKraken!"

	return 0

}

function github_pr() {

	# Creates a WIP PR from the CLI for the current branch to the target branch

	local BRANCH_SOURCE
	local BRANCH_TARGET="${1}"
	local TITLE="${2}"
	local BODY="${3}"

	BRANCH_SOURCE="$(git rev-parse --abbrev-ref HEAD)"
	BRANCH_TARGET="${BRANCH_TARGET:=trunk}"
	TITLE="${TITLE:=WIP}"
	BODY="${BODY:=WIP}"

	if ! checkBin gh; then
		writeLog "ERROR" "Please install the GitHub CLI 'gh'"
		return 1
	fi

	writeLog "INFO" "Creating a PR to merge from ${BRANCH_SOURCE} into branch ${BRANCH_TARGET}"

	gh pr create \
		--draft \
		--title "${TITLE}" \
		--body "${BODY}" \
		--assignee MAHDTech ||
		{
			writeLog "ERROR" "Failed to create PR for ${BRANCH_SOURCE}"
			return 1
		}

	return 0

}

function git_checkin() {

	# Removes the branch you have been working on post-PR
	# git checkin, get it?

	local BRANCH_SOURCE="${1}"
	local BRANCH_DEST="${2}"

	local -a BRANCHES_PROTECTED=(
		master
		main
		trunk
		environment/development
		environment/staging
		environment/production
	)

	if [[ ${BRANCH_SOURCE:-EMPTY} == "EMPTY" ]] || [[ ${BRANCH_SOURCE,,} == "current" ]]; then
		BRANCH_SOURCE="$(git rev-parse --abbrev-ref HEAD)"
	fi

	if [[ ${BRANCH_DEST:-EMPTY} == "EMPTY" ]]; then

		BRANCH_DEST="trunk"

		read -p "The source branch \"${BRANCH_SOURCE}\" will be checked into the branch \"${BRANCH_DEST}\". Are you sure? Y/N: " -n 1 -r CHOICE
		echo -e "\n"

		if [[ ! ${CHOICE} =~ ^[Yy] ]]; then
			writeLog "INFO" "No changes were made, goodbye!"
			return 1
		fi

	fi

	for BRANCH_PROTECTED in "${BRANCHES_PROTECTED[@]}"; do
		if [ "${BRANCH_SOURCE,,}" == "${BRANCH_PROTECTED,,}" ]; then
			writeLog "ERROR" "Not removing protected branch ${BRANCH_SOURCE}"
			return 1
		fi

	done

	writeLog "INFO" "Checking in completed branch ${BRANCH_SOURCE} and changing over to branch ${BRANCH_DEST}"

	git checkout "${BRANCH_DEST}" ||
		{
			writeLog "ERROR" "Failed to checkout ${BRANCH_DEST} branch"
			return 1
		}

	git branch --set-upstream-to=origin/${BRANCH_DEST} ${BRANCH_DEST} ||
		{
			writeLog "ERROR" "Failed to set upstream on ${BRANCH_DEST} branch"
			return 1
		}

	git pull --all --tags ||
		{
			writeLog "ERROR" "Failed to pull from origin"
			return 1
		}

	git_prune_all ||
		{
			writeLog "ERROR" "Failed to git_prune_all"
			return 1
		}

	git branch -D "${BRANCH_SOURCE}" ||
		{
			writeLog "ERROR" "Failed to delete branch ${BRANCH_SOURCE}"
			return 1
		}

	git branch --all ||
		{
			writeLog "ERROR" "Failed to list branches"
			return 1
		}

	return 0

}

function git_reset_delete() {

	# Resets the current branch and deletes any untracked files.

	local BRANCH_CURRENT
	BRANCH_CURRENT="$(git rev-parse --abbrev-ref HEAD)"

	read -p "Are you sure you want to reset the current branch ${BRANCH_CURRENT} to HEAD and delete any untracked files? Y/N: " -n 1 -r CHOICE
	echo -e "\n"

	if [[ ${CHOICE} =~ ^[Yy] ]]; then

		git reset HEAD --hard ||
			{
				writeLog "ERROR" "Failed to reset to HEAD"
				return 1
			}

		git clean --force -d ||
			{
				writeLog "ERROR" "Failed to clean untracked files"
				return 1
			}

		git status ||
			{
				writeLog "ERROR" "Failed to display current git status"
				return 1
			}

	else

		writeLog "INFO" "No changes were made."

	fi

	return 0

}

function git_set_head() {

	git remote set-head origin --auto ||
		{
			writeLog "ERR" "Failed to set HEAD automatically!"
			return 1
		}

}

function git_sync_fork() {

	# Synchronises a fork with the upstream repository.

	local UPSTREAM="upstream"
	local BRANCH="${1}"

	# Has a branch been provided?
	if [[ ${BRANCH:-EMPTY} == "EMPTY" ]]; then
		writeLog "ERROR" "Please provide the branch name to merge upstream changes into."
		git branch --all
		return 1
	fi

	# Has 'upstream' been configured as a git remote?
	if git remote -v | cut --fields 1 | grep -s "${UPSTREAM}"; then

		# Upstream has already been configured, fetch the latest changes.
		git fetch upstream || {
			writeLog "ERROR" "Failed to fetch upstream"
			return 1
		}

		git checkout "${BRANCH}" || {
			writeLog "ERROR" "Failed to checkout branch"
			return 1
		}

		git merge "upstream/${BRANCH}" || {
			writeLog "ERROR" "Failed to merge upstream changes"
			return 1
		}

	else

		writeLog "ERROR" "No upstream remote has been configured. Please set with 'git remote add upstream git@github.com/org/repo.git"
		return 1

	fi

	return 0

}

function git_folder_status() {

	local CURRENT_BRANCH

	while IFS= read -r -d '' FOLDER; do

		# Reset variables
		CURRENT_BRANCH=""

		writeLog "INFO" "Processing folder: ${FOLDER}"

		pushd "${FOLDER}" || {
			writeLog "ERROR" "Failed to push into ${FOLDER}"
			return 0
		}

		if [[ ! -d ".git" ]]; then
			writeLog "INFO" "Skipped folder: ${FOLDER} not a git directory"
			# shellcheck disable=2164
			popd
			continue
		fi

		# Ensure the currently known status is up to date
		writeLog "INFO" "Fetching repository"
		git fetch --all || {
			writeLog "WARN" "Failed to fetch repository, skipping repository!"
			# shellcheck disable=2164
			popd
			continue
		}

		# Determine the current branch
		CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

		if [[ ${CURRENT_BRANCH:-EMPTY} == "EMPTY" ]]; then
			writeLog "ERROR" "Failed to determine current branch"
			# shellcheck disable=2164
			popd
			continue
		else
			writeLog "INFO" "Checking current branch ${CURRENT_BRANCH}"
		fi

		# Is there changes that havn't been staged?
		git diff --exit-code || {
			writeLog "ERROR" "Failed folder: ${FOLDER}. Please stage, commit and push your changes before trying again."
			# stay in the dir for quick fix.
			# popd
			return 1
		}

		# Is there changes staged, but not committed?
		git diff --cached --exit-code || {
			writeLog "ERROR" "Failed folder: ${FOLDER}. Please commit changes and try again."
			# stay in the dir for quick fix.
			# popd
			return 1
		}

		# Is there changes committed but not pushed?
		if ! git rev-list "origin/${CURRENT_BRANCH}" | grep --silent "$(git rev-parse HEAD)"; then
			writeLog "ERROR" "Failed folder: ${FOLDER}. Please push your changes and try again."
			return 1
		fi

		popd || {
			writeLog "ERROR" "Failed to popd from ${FOLDER}"
			return 1
		}

	done < <(find . -maxdepth 1 -type d -print0)

	writeLog "INFO" "All folders checked, no files need staging or commiting"
	return 0

}

function github_download_release() {

	local GITHUB_ORG_REPO="$1"
	local ARCH="$2"
	local URL

	type fzf >/dev/null 2>&1 || {
		writeLog "ERROR" "Please install fzf and try again."
		return 1
	}

	if [ "${GITHUB_ORG_REPO:-EMPTY}" == "EMPTY" ]; then

		writeLog "ERROR" 'Please provide the ORG/REPO as $1'
		return 1

	else

		local GITHUB_ORG="${GITHUB_ORG_REPO%%/*}"
		local GITHUB_REPO="${GITHUB_ORG_REPO##*/}"

	fi

	URL_PATH="https://api.github.com/repos/${GITHUB_ORG}/${GITHUB_REPO}/releases/latest"

	URL=$(
		curl \
			--silent \
			--location \
			"${URL_PATH}" |
			egrep \
				"browser_download_url|tarball_url|zipball_url" |
			cut \
				--delim '"' \
				--field 4 |
			fzf
	)

	curl --silent --location --remote-name "${URL}" || {
		writeLog "ERROR" "Failed to download release!"
		return 1
	}

	return 0

}

function github_delete_workflows() {

	# Deletes all Workflow run results for a given org/repo
	# Reference: https://docs.github.com/en/rest/reference/actions#workflow-runs

	local URL
	local GITHUB_API
	local PAGE
	local GITHUB_ORG_REPO
	local WORKFLOW_RUNS
	local WORKFLOW
	local COUNTER
	local RESULT
	local HEADER_TOKEN
	local HEADER_APP

	GITHUB_API="https://api.github.com"
	PAGE="?&per_page=100"
	HEADER_APP="Accept: application/vnd.github.v3+json"

	# The expectation is to be passed org/repo as $1
	GITHUB_ORG_REPO="$1"

	if [ "${GITHUB_TOKEN:-EMPTY}" != "EMPTY" ]; then

		HEADER_TOKEN="Authorization: token ${GITHUB_TOKEN}"
		writeLog "INFO" "Using authenticated access to GitHub API"

	else

		HEADER_TOKEN=""
		writeLog "ERROR" 'No token is defined. Please set the PAT in $GITHUB_TOKEN'
		return 1

	fi

	if [ "${GITHUB_ORG_REPO:-EMPTY}" == "EMPTY" ]; then

		writeLog "ERROR" 'Please provide the ORG/REPO as $1'
		return 1

	else

		URL="${GITHUB_API}/repos/${GITHUB_ORG_REPO}/actions/runs"

	fi

	writeLog "INFO" "Obtaining a list of GitHub Workflow runs"

	LOOP="TRUE"
	while [[ ${LOOP} != "FALSE" ]]; do

		WORKFLOW_RUNS=""
		WORKFLOW_RUNS=$(curl --silent --request GET --header "${HEADER_TOKEN}" --header "${HEADER_APP}" "${URL}${PAGE}" | jq --raw-output .workflow_runs[].id)

		if [ "${WORKFLOW_RUNS:-EMPTY}" == "EMPTY" ]; then
			writeLog "ERROR" "Workflow run list is empty or failed to obtain the list from ${GITHUB_ORG_REPO}"
			LOOP="FALSE"
			continue
		fi

		COUNTER=0
		while IFS= read -r WORKFLOW; do

			writeLog "INFO" "Deleting Worklow ${WORKFLOW}"

			RESULT=""
			RESULT=$(curl --silent --write-out '%{http_code}' --output /dev/null --request DELETE --header "${HEADER_TOKEN}" --header "${HEADER_APP}" "${URL}/${WORKFLOW}")

			# '204 No content' means it worked
			if [ "${RESULT:-0}" -eq 204 ]; then

				writeLog "INFO" "Response: ${RESULT}"
				COUNTER=$((COUNTER + 1))

			else

				writeLog "ERROR" "Response: ${RESULT}"

			fi

		done <<<"${WORKFLOW_RUNS}"

		writeLog "INFO" "Deleted a total of ${COUNTER} Workflow Runs"

	done

	return 0

}

# shellcheck disable=2034
function github_query_projects() {

	# Queries all Projects from a given Organization and Repo
	# References:
	#		?
	# NOTES:
	#		Dirty hack for testing before ghb was created.

	local URL
	local GITHUB_API
	local PAGE
	local GITHUB_ORG_REPO
	local GITHUB_ORG
	local GITHUB_REPO
	local COUNTER
	local RESULT
	local HEADER_TOKEN
	local HEADER_JSON
	local GRAPHQL_FILES
	local GRAPHQL_FILE_QUERY
	local GRAPHQL_FILE_MUTATION
	local GRAPHQL_QUERY
	local GRAPHQL_MUTATION
	local PACKAGES
	local PACKAGE_VERSION_ID

	# The expectation is to be passed org/repo as $1
	GITHUB_ORG_REPO="${1}"

	if [ "${GITHUB_ORG_REPO:-EMPTY}" == "EMPTY" ]; then
		writeLog "ERROR" 'Please provide the ORG/REPO as $1'
		return 1
	fi

	# Split the org and repo
	GITHUB_ORG="${GITHUB_ORG_REPO%%/*}"
	GITHUB_REPO="${GITHUB_ORG_REPO##*/}"

	GITHUB_API="https://api.github.com/graphql"
	HEADER_JSON="Content-Type: application/json"

	# Handling JSON with heredocs is a PITA, use direct files instead.
	GRAPHQL_FILES="${HOME}/.config/github/graphql"
	GRAPHQL_FILE_QUERY="${GRAPHQL_FILES}/queries/projects.gql"

	GRAPHQL_QUERY=$(jq --null-input \
		--arg QUERY "$(sed -e "s/\$GITHUB_ORG/${GITHUB_ORG}/" -e "s/\$GITHUB_REPO/${GITHUB_REPO}/" "${GRAPHQL_FILE_QUERY}" | tr -d '\n')" \
		'{ query: $QUERY }')
	GRAPHQL_QUERY=${GRAPHQL_QUERY//[$'\t\r\n']/}
	GRAPHQL_QUERY=${GRAPHQL_QUERY//[[::space::]]/}

	if [ "${GITHUB_TOKEN:-EMPTY}" != "EMPTY" ]; then
		HEADER_TOKEN="Authorization: token ${GITHUB_TOKEN}"
		writeLog "INFO" "Using authenticated access to GitHub API"
	else
		HEADER_TOKEN=""
		writeLog "ERROR" 'No token is defined. Please set the PAT in $GITHUB_TOKEN'
		return 1
	fi

	writeLog "INFO" "Obtaining a list of GitHub Projects from Org ${GITHUB_ORG} and Repo ${GITHUB_REPO}"

	curl \
		--request POST \
		--header "${HEADER_TOKEN}" \
		--data "${GRAPHQL_QUERY}" \
		"${GITHUB_API}" ||
		writeLog "ERROR" "Failed to obtain list of GitHub Projects"
	#| jq -r '.data.repository.packages.nodes[].versions.nodes[].version')

	return 0

}

# shellcheck disable=2034
function github_delete_packages_old() {

	# Deletes all packages from a given GitHub org
	# References:
	#		https://docs.github.com/en/packages/manage-packages/deleting-a-package#deleting-a-version-of-a-private-package-with-graphql
	# NOTES:
	#		This does NOT work with the new GitHub ghcr.io container registry

	local URL
	local GITHUB_API
	local PAGE
	local GITHUB_ORG_REPO
	local GITHUB_ORG
	local GITHUB_REPO
	local COUNTER
	local RESULT
	local HEADER_TOKEN
	local HEADER_JSON
	local HEADER_DELETE
	local GRAPHQL_FILES
	local GRAPHQL_FILE_QUERY
	local GRAPHQL_FILE_MUTATION
	local GRAPHQL_QUERY
	local GRAPHQL_MUTATION
	local PACKAGES
	local PACKAGE_VERSION_ID

	# The expectation is to be passed org/repo as $1
	GITHUB_ORG_REPO="${1}"

	# Split the org and repo
	GITHUB_ORG="${GITHUB_ORG_REPO%%/*}"
	GITHUB_REPO="${GITHUB_ORG_REPO##*/}"

	GITHUB_API="https://api.github.com/graphql"
	PAGE="?&per_page=100"
	HEADER_JSON="Content-Type: application/json"
	HEADER_DELETE="Accept: application/vnd.github.package-deletes-preview+json"

	# Handling JSON with heredocs is a PITA, use direct files instead.
	GRAPHQL_FILES="${HOME}/.config/github/graphql"
	GRAPHQL_FILE_QUERY="${GRAPHQL_FILES}/queries/packages.gql"
	GRAPHQL_FILE_MUTATION="${GRAPHQL_FILES}/mutations/packages.gql"

	GRAPHQL_QUERY=$(jq --null-input \
		--arg QUERY "$(sed -e "s/\$GITHUB_ORG/${GITHUB_ORG}/" -e "s/\$GITHUB_REPO/${GITHUB_REPO}/" "${GRAPHQL_FILE_QUERY}" | tr -d '\n')" \
		'{ query: $QUERY }')
	GRAPHQL_QUERY=${GRAPHQL_QUERY//[$'\t\r\n']/}
	GRAPHQL_QUERY=${GRAPHQL_QUERY//[[::space::]]/}

	if [ "${GITHUB_TOKEN:-EMPTY}" != "EMPTY" ]; then

		HEADER_TOKEN="Authorization: token ${GITHUB_TOKEN}"
		writeLog "INFO" "Using authenticated access to GitHub API"

	else

		HEADER_TOKEN=""
		writeLog "ERROR" 'No token is defined. Please set the PAT in $GITHUB_TOKEN'
		return 1

	fi

	if [ "${GITHUB_ORG:-EMPTY}" == "EMPTY" ]; then

		writeLog "ERROR" 'Please provide the ORG as $1'
		return 1

	fi

	read -p "Are you sure you want to remove all packages from the GitHub ${GITHUB_ORG} organization under repo ${GITHUB_REPO} Y/N: " -n 1 -r CHOICE
	echo -e "\n"

	if [[ ! ${CHOICE} =~ ^[Yy] ]]; then

		writeLog "INFO" "No changes have been made, goodbye!"
		return 1

	fi

	writeLog "INFO" "Obtaining a list of GitHub Packages"

	PACKAGES=""
	PACKAGES=$(curl --silent --request POST --head "${HEADER_JSON}" --header "${HEADER_TOKEN}" --data "${GRAPHQL_QUERY}" "${GITHUB_API}" | jq -r '.data.repository.packages.nodes[].versions.nodes[].version')

	if [ "${PACKAGES:-EMPTY}" == "EMPTY" ]; then
		writeLog "ERROR" "Failed to obtain list of packages from GitHub organization ${ORG}"
		return 1
	fi

	COUNTER=0
	while IFS= read -r PACKAGE_VERSION_ID; do

		writeLog "INFO" "Deleting Package ${PACKAGE_VERSION_ID}"

		unset GRAPHQL_MUTATION
		GRAPHQL_MUTATION=$(jq --null-input \
			--arg QUERY "$(sed -e "s/\$PACKAGE_VERSION_ID/${PACKAGE_VERSION_ID}/" -e "s/\$GITHUB_REPO/${GITHUB_REPO}/" "${GRAPHQL_FILE_QUERY}" | tr -d '\n')" \
			'{ query: $QUERY }')
		GRAPHQL_MUTATION=${GRAPHQL_MUTATION//[$'\t\r\n']/}
		GRAPHQL_MUTATION=${GRAPHQL_MUTATION//[[::space::]]/}

		unset RESULT
		RESULT=$(curl --silent --write-out '%{http_code}' --output /dev/null --request POST --header "${HEADER_TOKEN}" --header "${HEADER_DELETE}" --data "${GRAPHQL_MUTATION}" "${GITHUB_API}")

		# '204 No content' means it worked
		if [ "${RESULT:-0}" -eq 204 ]; then

			writeLog "INFO" "Response: ${RESULT}"
			COUNTER=$((COUNTER + 1))

		else

			writeLog "ERROR" "Response: ${RESULT}"

		fi

	done <<<"${PACKAGES}"

	writeLog "INFO" "Deleted a total of ${COUNTER} Workflow Runs"

	return 0

}

function github_get_label() {

	# Returns true if the provided label name exists.

	local GITHUB_ORG_REPO="${1}"
	local GITHUB_LABEL_NAME="${2}"
	local GITHUB_ORG
	local GITHUB_REPO
	local GITHUB_API
	local URL
	local RESULT
	local HEADER_TOKEN
	local HEADER_APP

	# Split the org and repo
	GITHUB_ORG="${GITHUB_ORG_REPO%%/*}"
	GITHUB_REPO="${GITHUB_ORG_REPO##*/}"

	GITHUB_API="https://api.github.com"
	HEADER_APP="Accept: application/vnd.github.v3+json"

	if [ "${GITHUB_TOKEN:-EMPTY}" != "EMPTY" ]; then

		HEADER_TOKEN="Authorization: token ${GITHUB_TOKEN}"
		writeLog "INFO" "Using authenticated access to GitHub API"

	else

		HEADER_TOKEN=""
		writeLog "ERROR" 'No token is defined. Please set the PAT in $GITHUB_TOKEN'
		return 1

	fi

	if [[ ${GITHUB_LABEL_NAME:-EMPTY} == "EMPTY" ]]; then

		writeLog "ERROR" 'Please provide a valid label name as $2'
		return 1

	fi

	if [ "${GITHUB_ORG_REPO:-EMPTY}" == "EMPTY" ]; then

		writeLog "ERROR" 'Please provide the ORG/REPO as $1'
		return 1

	else

		URL="${GITHUB_API}/repos/${GITHUB_ORG_REPO}/labels/${GITHUB_LABEL_NAME}"

	fi

	# Does the label exist?
	RESULT=$(curl --silent --write-out '%{http_code}' --output /dev/null --request POST --header "${HEADER_TOKEN}" --header "${HEADER_APP}" "${URL}")

	# '200' means the label exists
	if [ "${RESULT:-0}" -eq 200 ]; then

		writeLog "INFO" "The GitHub Label ${GITHUB_LABEL_NAME} already exists."
		return 0

	else

		writeLog "INFO" "The GitHub Label ${GITHUB_LABEL_NAME} does not exist."
		return 1

	fi

}

function github_create_label() {

	# Creates a label on a GitHub project from a JSON file.

	local GITHUB_ORG_REPO="${1}"
	local GITHUB_LABEL_FILE="${2}"
	local GITHUB_ORG
	local GITHUB_REPO
	local GITHUB_API
	local URL
	local RESULT
	local HEADER_TOKEN
	local HEADER_APP

	# Split the org and repo
	GITHUB_ORG="${GITHUB_ORG_REPO%%/*}"
	GITHUB_REPO="${GITHUB_ORG_REPO##*/}"

	GITHUB_API="https://api.github.com"
	PAGE="?&per_page=100"
	HEADER_APP="Accept: application/vnd.github.v3+json"

	if [ "${GITHUB_TOKEN:-EMPTY}" != "EMPTY" ]; then

		HEADER_TOKEN="Authorization: token ${GITHUB_TOKEN}"
		writeLog "INFO" "Using authenticated access to GitHub API"

	else

		HEADER_TOKEN=""
		writeLog "ERROR" 'No token is defined. Please set the PAT in $GITHUB_TOKEN'
		return 1

	fi

	if [ "${GITHUB_ORG_REPO:-EMPTY}" == "EMPTY" ]; then

		writeLog "ERROR" 'Please provide the ORG/REPO as $1'
		return 1

	else

		URL="${GITHUB_API}/repos/${GITHUB_ORG_REPO}/labels"

	fi

	if [[ ! -f ${GITHUB_LABEL_FILE} ]]; then

		writeLog "ERROR" 'Please provide a valid label.json file as $2'
		return 1

	fi

	# Create the label
	RESULT=$(curl --silent --write-out '%{http_code}' --output /dev/null --request POST --header "${HEADER_TOKEN}" --header "${HEADER_APP}" "${URL}" --data "@${GITHUB_LABEL_FILE}")

	# '201 Created' means it worked
	if [ "${RESULT:-0}" -eq 201 ]; then

		writeLog "INFO" "Label created successfully"

	else

		writeLog "ERROR" "Failed to create Label"

	fi

	return 0

}

function github_set_defaults() {

	# An opinionated set of defaults for any GitHub project.

	# Example: salt-labs/hello-world
	local GITHUB_ORG_REPO="${1}"

	# Split the org and repo
	GITHUB_ORG="${GITHUB_ORG_REPO%%/*}"
	GITHUB_REPO="${GITHUB_ORG_REPO##*/}"

	local GITHUB_DIR="${HOME}/.config/GitHub"
	local GITHUB_LABELS="${GITHUB_DIR}/Labels"
	local GITHUB_LABEL_NAME

	# Apply Labels
	for LABEL in "${GITHUB_LABELS}/"*.json; do

		# Extract the label name
		GITHUB_LABEL_NAME=$(jq --raw-output .name "${LABEL}")

		# Check if the label already exists
		if ! github_get_label "${GITHUB_ORG_REPO}" "${GITHUB_LABEL_NAME}"; then

			writeLog "INFO" "Creating Label ${LABEL}"

			github_create_label "${GITHUB_ORG_REPO}" "${LABEL}" || {
				writeLog "ERROR" "Failed to create Label ${LABEL}"
				return 1
			}

		fi

	done

	# Apply X

	return 0

}
