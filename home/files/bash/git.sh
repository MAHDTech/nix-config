#!/usr/bin/env bash

##################################################
# Name: git
# Description: Contains the git related functions
##################################################

export -a _GIT_PROTECTED_BRANCHES=(
	environment/development
	environment/production
	environment/staging
	main
	master
	trunk
)

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
			PARAMS[INDEX]="${PARAMS[$INDEX]}"

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
		writeLog "ERROR" "Please provide a branch to squash as param 1"
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
	git commit --no-verify -am "chore: Squashed branch" "${PARAMS[@]}" || {
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
	read -r -p "Press [Enter] to continue....."

	writeLog "INFO" "Stage the changes to .gitmodules"
	git add .gitmodules ||
		{
			writeLog "ERROR" "Failed to stage .gitmodules"
			return 1
		}
	read -r -p "Press [Enter] to continue....."

	writeLog "INFO" "Remove the section from .git/config"
	vim ".git/config"
	read -r -p "Press [Enter] to continue....."

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

		git commit --no-gpg-sign --no-verify -am "chore: removed submodule" ||
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
		writeLog "ERROR" "Please provide the large file path as param 1. This should be the relative filename based on the git dir context."
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
	# The intention is to checkout master/main/trunk, and then run this post-merge
	# Protected branches are defined in the global _GIT_PROTECTED_BRANCHES array

	local CURRENT_BRANCH
	local BRANCH
	local -a BRANCHES_TO_DELETE=()
	local CONFIRM_DELETE="false"

	# Get current branch
	CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

	if [[ ${CURRENT_BRANCH:-EMPTY} == "EMPTY" ]]; then
		writeLog "ERROR" "Failed to determine current branch"
		return 1
	fi

	writeLog "INFO" "Looking for branches merged into ${CURRENT_BRANCH}"

	# Get list of merged branches, excluding current branch and protected branches
	while IFS= read -r BRANCH; do

		# Remove leading/trailing whitespace and asterisk
		BRANCH=$(echo "${BRANCH}" | sed 's/^[* ]*//' | sed 's/[ ]*$//')

		# Skip empty lines
		[[ -z ${BRANCH} ]] && continue

		# Skip current branch
		[[ ${BRANCH} == "${CURRENT_BRANCH}" ]] && continue

		# Check if branch is protected
		local IS_PROTECTED="false"
		for PROTECTED in "${_GIT_PROTECTED_BRANCHES[@]}"; do
			if [[ ${BRANCH,,} == "${PROTECTED,,}" ]]; then
				IS_PROTECTED="true"
				break
			fi
		done

		# If not protected, add to deletion list
		if [[ ${IS_PROTECTED} == "false" ]]; then
			BRANCHES_TO_DELETE+=("${BRANCH}")
		fi

	done < <(git branch --merged)

	# Show what we found
	if [[ ${#BRANCHES_TO_DELETE[@]} -eq 0 ]]; then
		writeLog "INFO" "No merged branches found that can be safely deleted"
		return 0
	fi

	writeLog "INFO" "Found ${#BRANCHES_TO_DELETE[@]} merged branches that can be deleted:"
	for BRANCH in "${BRANCHES_TO_DELETE[@]}"; do
		writeLog "INFO" "  - ${BRANCH}"
	done

	# Ask for confirmation
	read -r -p "Do you want to delete these branches? (y/N): " CONFIRM_DELETE
	echo

	if [[ ${CONFIRM_DELETE,,} =~ ^(y|yes)$ ]]; then

		local SUCCESS_COUNT=0
		local FAILURE_COUNT=0

		for BRANCH in "${BRANCHES_TO_DELETE[@]}"; do
			writeLog "INFO" "Deleting branch: ${BRANCH}"

			if git branch -d "${BRANCH}" 2>/dev/null; then
				writeLog "INFO" "Successfully deleted branch: ${BRANCH}"
				((SUCCESS_COUNT++))
			else
				writeLog "WARN" "Failed to delete branch: ${BRANCH} (may have unmerged changes)"
				((FAILURE_COUNT++))
			fi
		done

		writeLog "INFO" "Deletion complete. Successful: ${SUCCESS_COUNT}, Failed: ${FAILURE_COUNT}"

	else
		writeLog "INFO" "Branch deletion cancelled"
	fi

	return 0

}

function git_pull_all() {

	# Pulls every branch from origin using the same name as the local branch
	# Also optionally creates local tracking branches for remote branches that don't exist locally

	local CURRENT_BRANCH
	local BRANCH
	local REMOTE_BRANCH
	local CREATE_MISSING="${1:-false}"
	local SUCCESS_COUNT=0
	local FAILURE_COUNT=0
	local CREATED_COUNT=0

	# Get current branch to restore later
	CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

	if [[ ${CURRENT_BRANCH:-EMPTY} == "EMPTY" ]]; then
		writeLog "ERROR" "Failed to determine current branch"
		return 1
	fi

	writeLog "INFO" "Fetching all remotes to get latest information"

	# First, fetch all remotes to ensure we have the latest remote information
	git fetch --all --prune || {
		writeLog "ERROR" "Failed to fetch from remotes"
		return 1
	}

	writeLog "INFO" "Pulling updates for all local branches"

	# Pull updates for all existing local branches that have remotes
	while IFS= read -r BRANCH; do

		# Remove leading/trailing whitespace and asterisk
		BRANCH=$(echo "${BRANCH}" | sed 's/^[* ]*//' | sed 's/[ ]*$//')

		# Skip empty lines
		[[ -z ${BRANCH} ]] && continue

		writeLog "INFO" "Processing branch: ${BRANCH}"

		# Check if this branch has a remote tracking branch
		REMOTE_BRANCH=$(git rev-parse --abbrev-ref "${BRANCH}@{upstream}" 2>/dev/null)

		if [[ -n ${REMOTE_BRANCH} ]]; then

			writeLog "INFO" "Pulling ${BRANCH} from ${REMOTE_BRANCH}"

			# Checkout the branch and pull
			if git checkout "${BRANCH}" >/dev/null 2>&1; then

				if git pull 2>/dev/null; then
					writeLog "INFO" "Successfully pulled ${BRANCH}"
					((SUCCESS_COUNT++))
				else
					writeLog "WARN" "Failed to pull ${BRANCH}"
					((FAILURE_COUNT++))
				fi

			else
				writeLog "WARN" "Failed to checkout ${BRANCH}"
				((FAILURE_COUNT++))
			fi

		else
			writeLog "INFO" "Branch ${BRANCH} has no upstream tracking branch, skipping"
		fi

	done < <(git branch --format='%(refname:short)')

	# Optionally create local branches for remote branches that don't exist locally
	if [[ ${CREATE_MISSING,,} =~ ^(true|yes|y|1)$ ]]; then

		writeLog "INFO" "Creating local tracking branches for remote branches"

		# Get all remote branches (excluding HEAD)
		while IFS= read -r REMOTE_BRANCH; do

			# Remove leading/trailing whitespace
			REMOTE_BRANCH=$(echo "${REMOTE_BRANCH}" | sed 's/^[ ]*//' | sed 's/[ ]*$//')

			# Skip empty lines and HEAD references
			[[ -z ${REMOTE_BRANCH} ]] && continue
			[[ ${REMOTE_BRANCH} =~ HEAD ]] && continue

			# Extract branch name (remove origin/ prefix)
			BRANCH="${REMOTE_BRANCH#origin/}"

			# Skip if local branch already exists
			if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
				continue
			fi

			writeLog "INFO" "Creating local branch ${BRANCH} to track ${REMOTE_BRANCH}"

			if git checkout -b "${BRANCH}" "${REMOTE_BRANCH}" >/dev/null 2>&1; then
				writeLog "INFO" "Successfully created tracking branch ${BRANCH}"
				((CREATED_COUNT++))
			else
				writeLog "WARN" "Failed to create tracking branch ${BRANCH}"
			fi

		done < <(git branch -r --format='%(refname:short)')

	fi

	# Return to original branch
	writeLog "INFO" "Returning to original branch: ${CURRENT_BRANCH}"
	git checkout "${CURRENT_BRANCH}" >/dev/null 2>&1 || {
		writeLog "WARN" "Failed to return to original branch ${CURRENT_BRANCH}"
	}

	# Summary
	writeLog "INFO" "Pull operation complete:"
	writeLog "INFO" "  - Successfully pulled: ${SUCCESS_COUNT} branches"
	writeLog "INFO" "  - Failed to pull: ${FAILURE_COUNT} branches"
	if [[ ${CREATE_MISSING,,} =~ ^(true|yes|y|1)$ ]]; then
		writeLog "INFO" "  - Created tracking branches: ${CREATED_COUNT} branches"
	fi

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

		writeLog "INFO" "Please provide the branch name as param 1 and not extra args."
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
	git commit --no-verify --message "chore: Initialize ${BRANCH} branch" "${PARAMS[@]}" ||
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

function git_checkin() {

	# Removes the branch you have been working on post-PR
	# git checkin, get it?

	local BRANCH_SOURCE
	local BRANCH_DEST

	BRANCH_SOURCE="$(git rev-parse --abbrev-ref HEAD)"
	BRANCH_DEST="${1}"

	# Make sure the destination branch is not empty.
	if [[ ${BRANCH_DEST:-EMPTY} == "EMPTY" ]]; then
		writeLog "ERROR" "Please provide the branch name to merge upstream changes into."
		return 1
	fi

	# Make sure the source and destination branches are not the same.
	if [[ ${BRANCH_SOURCE:-EMPTY} == "${BRANCH_DEST:-EMPTY}" ]]; then
		writeLog "ERROR" "Source and destination branches cannot be the same."
		return 1
	fi

	read -p "The source branch \"${BRANCH_SOURCE}\" will be checked into the branch \"${BRANCH_DEST}\". Are you sure? Y/N: " -n 1 -r CHOICE
	echo -e "\n"

	if [[ ! ${CHOICE} =~ ^[Yy] ]]; then
		writeLog "INFO" "No changes were made, goodbye!"
		return 1
	fi

	for BRANCH_PROTECTED in "${_GIT_PROTECTED_BRANCHES[@]}"; do
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

	git branch --set-upstream-to=origin/"${BRANCH_DEST}" "${BRANCH_DEST}" ||
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

		# Is there changes that haven't been staged?
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

	writeLog "INFO" "All folders checked, no files need staging or committing"
	return 0

}
