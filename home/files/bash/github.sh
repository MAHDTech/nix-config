#!/usr/bin/env bash

##################################################
# Name: github
# Description: GitHub related functions using gh CLI
##################################################

function github_pr() {

	# Creates a WIP PR from the CLI for the current branch to the target branch

	local BRANCH_TARGET="${1}"
	local TITLE="${2}"
	local BODY="${3}"

	BRANCH_TARGET="${BRANCH_TARGET:-trunk}"
	TITLE="${TITLE:-WIP}"
	BODY="${BODY:-WIP}"

	if ! command -v gh &>/dev/null; then
		writeLog "ERROR" "Please install the GitHub CLI 'gh'"
		return 1
	fi

	writeLog "INFO" "Creating a draft PR to merge into branch ${BRANCH_TARGET}"

	gh pr create \
		--draft \
		--base "${BRANCH_TARGET}" \
		--title "${TITLE}" \
		--body "${BODY}" \
		--assignee "@me" || {
		writeLog "ERROR" "Failed to create PR"
		return 1
	}

	return 0

}

function github_download_release() {

	# Downloads a release asset from a GitHub repository

	local GITHUB_ORG_REPO="$1"
	local TAG="${2:-latest}"

	if ! command -v gh &>/dev/null; then
		writeLog "ERROR" "Please install the GitHub CLI 'gh'"
		return 1
	fi

	if [[ ${GITHUB_ORG_REPO:-EMPTY} == "EMPTY" ]]; then
		writeLog "ERROR" "Please provide the ORG/REPO as param 1"
		return 1
	fi

	writeLog "INFO" "Downloading release assets from ${GITHUB_ORG_REPO}"

	if [[ ${TAG} == "latest" ]]; then
		gh release download \
			--repo "${GITHUB_ORG_REPO}" \
			--pattern "*" || {
			writeLog "ERROR" "Failed to download release assets"
			return 1
		}
	else
		gh release download "${TAG}" \
			--repo "${GITHUB_ORG_REPO}" \
			--pattern "*" || {
			writeLog "ERROR" "Failed to download release assets for tag ${TAG}"
			return 1
		}
	fi

	return 0

}

function github_delete_workflows() {

	# Deletes all Workflow run results for a given org/repo

	local GITHUB_ORG_REPO="$1"
	local WORKFLOW_STATUS="${2:-}"
	local COUNTER_SUCCESS=0
	local COUNTER_FAILURE=0

	if ! command -v gh &>/dev/null; then
		writeLog "ERROR" "Please install the GitHub CLI 'gh'"
		return 1
	fi

	if [[ ${GITHUB_ORG_REPO:-EMPTY} == "EMPTY" ]]; then
		writeLog "ERROR" "Please provide the ORG/REPO as param 1"
		return 1
	fi

	writeLog "INFO" "Obtaining a list of GitHub Workflow runs"

	local WORKFLOW_RUNS
	if [[ -n ${WORKFLOW_STATUS} ]]; then
		WORKFLOW_RUNS=$(gh run list --repo "${GITHUB_ORG_REPO}" --limit 100 --status "${WORKFLOW_STATUS}" --json databaseId --jq '.[].databaseId')
	else
		WORKFLOW_RUNS=$(gh run list --repo "${GITHUB_ORG_REPO}" --limit 100 --json databaseId --jq '.[].databaseId')
	fi

	if [[ -z ${WORKFLOW_RUNS} ]]; then
		writeLog "INFO" "No workflow runs found to delete"
		return 0
	fi

	while IFS= read -r RUN_ID; do

		[[ -z ${RUN_ID} ]] && continue

		writeLog "INFO" "Deleting Workflow run ${RUN_ID}"

		if gh run delete "${RUN_ID}" --repo "${GITHUB_ORG_REPO}" 2>/dev/null; then
			writeLog "INFO" "Successfully deleted run ${RUN_ID}"
			((COUNTER_SUCCESS++))
		else
			writeLog "WARN" "Failed to delete run ${RUN_ID}"
			((COUNTER_FAILURE++))
		fi

	done <<<"${WORKFLOW_RUNS}"

	writeLog "INFO" "Deleted a total of ${COUNTER_SUCCESS} Workflow Runs."
	[[ ${COUNTER_FAILURE} -gt 0 ]] && writeLog "WARN" "Failed to delete ${COUNTER_FAILURE} Workflow Runs."

	return 0

}

function github_query_projects() {

	# Queries all Projects from a given Organization and Repo

	local GITHUB_ORG_REPO="${1}"

	if ! command -v gh &>/dev/null; then
		writeLog "ERROR" "Please install the GitHub CLI 'gh'"
		return 1
	fi

	if [[ ${GITHUB_ORG_REPO:-EMPTY} == "EMPTY" ]]; then
		writeLog "ERROR" "Please provide the ORG/REPO as param 1"
		return 1
	fi

	writeLog "INFO" "Obtaining a list of GitHub Projects from ${GITHUB_ORG_REPO}"

	gh project list --repo "${GITHUB_ORG_REPO}" || {
		writeLog "ERROR" "Failed to list projects"
		return 1
	}

	return 0

}

function github_delete_packages() {

	# Deletes package versions from a given GitHub org/repo

	local GITHUB_ORG_REPO="${1}"
	local PACKAGE_NAME="${2}"
	local PACKAGE_TYPE="${3:-container}"

	if ! command -v gh &>/dev/null; then
		writeLog "ERROR" "Please install the GitHub CLI 'gh'"
		return 1
	fi

	if [[ ${GITHUB_ORG_REPO:-EMPTY} == "EMPTY" ]]; then
		writeLog "ERROR" "Please provide the ORG/REPO as param 1"
		return 1
	fi

	if [[ ${PACKAGE_NAME:-EMPTY} == "EMPTY" ]]; then
		writeLog "ERROR" "Please provide the package name as param 2"
		return 1
	fi

	local GITHUB_ORG="${GITHUB_ORG_REPO%%/*}"

	read -p "Are you sure you want to delete versions of package ${PACKAGE_NAME} from ${GITHUB_ORG}? Y/N: " -n 1 -r CHOICE
	echo

	if [[ ! ${CHOICE} =~ ^[Yy] ]]; then
		writeLog "INFO" "No changes have been made, goodbye!"
		return 0
	fi

	writeLog "INFO" "Listing package versions for ${PACKAGE_NAME}"

	local VERSIONS
	VERSIONS=$(gh api \
		--method GET \
		"/orgs/${GITHUB_ORG}/packages/${PACKAGE_TYPE}/${PACKAGE_NAME}/versions" \
		--jq '.[].id' 2>/dev/null)

	if [[ -z ${VERSIONS} ]]; then
		writeLog "INFO" "No package versions found"
		return 0
	fi

	local COUNTER=0
	while IFS= read -r VERSION_ID; do

		[[ -z ${VERSION_ID} ]] && continue

		writeLog "INFO" "Deleting package version ${VERSION_ID}"

		if gh api \
			--method DELETE \
			"/orgs/${GITHUB_ORG}/packages/${PACKAGE_TYPE}/${PACKAGE_NAME}/versions/${VERSION_ID}" 2>/dev/null; then
			writeLog "INFO" "Successfully deleted version ${VERSION_ID}"
			((COUNTER++))
		else
			writeLog "WARN" "Failed to delete version ${VERSION_ID}"
		fi

	done <<<"${VERSIONS}"

	writeLog "INFO" "Deleted ${COUNTER} package versions"

	return 0

}

function github_get_label() {

	# Returns true if the provided label name exists.

	local GITHUB_ORG_REPO="${1}"
	local GITHUB_LABEL_NAME="${2}"

	if ! command -v gh &>/dev/null; then
		writeLog "ERROR" "Please install the GitHub CLI 'gh'"
		return 1
	fi

	if [[ ${GITHUB_ORG_REPO:-EMPTY} == "EMPTY" ]]; then
		writeLog "ERROR" "Please provide the ORG/REPO as param 1"
		return 1
	fi

	if [[ ${GITHUB_LABEL_NAME:-EMPTY} == "EMPTY" ]]; then
		writeLog "ERROR" "Please provide a valid label name as param 2"
		return 1
	fi

	if gh label list --repo "${GITHUB_ORG_REPO}" --search "${GITHUB_LABEL_NAME}" --json name --jq '.[].name' 2>/dev/null | grep -qx "${GITHUB_LABEL_NAME}"; then
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

	if ! command -v gh &>/dev/null; then
		writeLog "ERROR" "Please install the GitHub CLI 'gh'"
		return 1
	fi

	if [[ ${GITHUB_ORG_REPO:-EMPTY} == "EMPTY" ]]; then
		writeLog "ERROR" "Please provide the ORG/REPO as param 1"
		return 1
	fi

	if [[ ! -f ${GITHUB_LABEL_FILE} ]]; then
		writeLog "ERROR" "Please provide a valid label.json file as param 2"
		return 1
	fi

	local LABEL_NAME
	local LABEL_COLOR
	local LABEL_DESC

	LABEL_NAME=$(jq --raw-output '.name' "${GITHUB_LABEL_FILE}")
	LABEL_COLOR=$(jq --raw-output '.color' "${GITHUB_LABEL_FILE}")
	LABEL_DESC=$(jq --raw-output '.description // ""' "${GITHUB_LABEL_FILE}")

	writeLog "INFO" "Creating label ${LABEL_NAME}"

	gh label create "${LABEL_NAME}" \
		--repo "${GITHUB_ORG_REPO}" \
		--color "${LABEL_COLOR}" \
		--description "${LABEL_DESC}" || {
		writeLog "ERROR" "Failed to create Label ${LABEL_NAME}"
		return 1
	}

	writeLog "INFO" "Label created successfully"

	return 0

}

function github_set_defaults() {

	# An opinionated set of defaults for any GitHub project.

	local GITHUB_ORG_REPO="${1}"

	if ! command -v gh &>/dev/null; then
		writeLog "ERROR" "Please install the GitHub CLI 'gh'"
		return 1
	fi

	if [[ ${GITHUB_ORG_REPO:-EMPTY} == "EMPTY" ]]; then
		writeLog "ERROR" "Please provide the ORG/REPO as param 1"
		return 1
	fi

	local GITHUB_DIR="${HOME}/.config/GitHub"
	local GITHUB_LABELS="${GITHUB_DIR}/Labels"
	local GITHUB_LABEL_NAME

	if [[ ! -d ${GITHUB_LABELS} ]]; then
		writeLog "WARN" "Labels directory ${GITHUB_LABELS} does not exist"
		return 0
	fi

	# Apply Labels
	for LABEL in "${GITHUB_LABELS}/"*.json; do

		[[ ! -f ${LABEL} ]] && continue

		# Extract the label name
		GITHUB_LABEL_NAME=$(jq --raw-output .name "${LABEL}")

		# Check if the label already exists
		if ! github_get_label "${GITHUB_ORG_REPO}" "${GITHUB_LABEL_NAME}"; then

			writeLog "INFO" "Creating Label ${GITHUB_LABEL_NAME}"

			github_create_label "${GITHUB_ORG_REPO}" "${LABEL}" || {
				writeLog "ERROR" "Failed to create Label ${GITHUB_LABEL_NAME}"
				return 1
			}

		fi

	done

	return 0

}
