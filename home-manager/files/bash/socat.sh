#!/usr/bin/env bash

# Reference: https://gist.github.com/dinvlad/a62d44325fa2b989a046fe984a06e140
function listen_socket() {

	SOCKET_PATH="$1" && shift
	FORK_ARGS="${SOCKET_PATH},fork"
	EXEC_ARGS="ssh-agent $*"

	if ! ps x | grep -v grep | grep -q "${FORK_ARGS}"; then
		writeLog "INFO" "Removing old socket: ${SOCKET_PATH}"
		rm -f "${SOCKET_PATH}"

		writeLog "INFO" "Starting socat: ${FORK_ARGS} -> ${EXEC_ARGS}"
		(setsid nohup socat "UNIX-LISTEN:${FORK_ARGS}" "EXEC:${EXEC_ARGS}" &>/dev/null &)
	fi

	return 0

}

function setup_sockets() {

	writeLog "INFO" "Setting up SSH socket"

	if [[ ${SSH_AUTH_SOCK:-EMPTY} != "EMPTY" ]]; then
		writeLog "INFO" "Setting up socat on ${SSH_AUTH_SOCK}"
		listen_socket "${SSH_AUTH_SOCK}"
	else
		writeLog "WARN" "No existing SSH_AUTH_SOCK found"
	fi

	writeLog "INFO" "Setting up GPG sockets"

	if [[ ${GPG_AGENT_SOCK:-EMPTY} != "EMPTY" ]]; then
		writeLog "INFO" "Setting up socat on ${GPG_AGENT_SOCK}"
	else
		GPG_AGENT_SOCK="$(gpgconf --list-dirs agent-socket)"
	fi
	listen_socket "${GPG_AGENT_SOCK}" --gpg S.gpg-agent

	if [[ ${GPG_AGENT_SOCK_EXTRA:-EMPTY} != "EMPTY" ]]; then
		writeLog "INFO" "Setting up socat on ${GPG_AGENT_SOCK_EXTRA}"
		listen_socket "${GPG_AGENT_SOCK_EXTRA}" --gpg S.gpg-agent.extra
	else
		GPG_AGENT_SOCK_EXTRA="$(gpgconf --list-dirs agent-extra-socket)"
	fi
	listen_socket "${GPG_AGENT_SOCK_EXTRA}" --gpg S.gpg-agent.extra

	return 0

}
