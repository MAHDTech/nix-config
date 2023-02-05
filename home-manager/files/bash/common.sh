#!/usr/bin/env bash

##################################################
# Name: common
# Description: Contains assorted user functions loaded into the Shell on startup
##################################################

function pushd() {

	local DIR="$*"

	command pushd "${DIR}" > /dev/null || {
		writeLog "ERROR" "Failed to push into ${DIR}"
		return 1
	}

	return 0

}

function popd() {

	command popd > /dev/null || {
		writeLog "ERROR" "Failed to pop directory from stack"
		dirs
		return 1
	}

}

function sync-to-confluence() {

	local MARKDOWN_FILE
	local CONFLUENCE_SPACE

	MARKDOWN_FILE="$1"
	CONFLUENCE_SPACE="$2"

	if [[ $# -ne 2 ]];
	then

		writeLog "WARN" "Incorrect usage. Exactly 2 parameters are required"

		echo -e "\nsync-to-confluence \<markdown file> <confluence space>"
		return 1

	fi

	go-markdown2confluence --space "${CONFLUENCE_SPACE}" --modified-since 30 --parent "Markdown" "${MARKDOWN_FILE}" \
		|| { writeLog "ERROR" "Failed to sync markdown to confluence space" ; return 1 ; }

	return 0

}

function set_win_title() {

	echo -ne "\033]0; $(basename "${PWD}") \007"

	return 0
}

function exit_zsh_session() {

	writeLog "DEBUG" "Executing .zlogout"

	# shellcheck source=${HOME}/.zlogout
	source "${HOME}/.zlogout"

}

function exit_bash_session() {

	writeLog "DEBUG" "Executing .bash_logout"

	# shellcheck source=${HOME}/.bash_logout
	. "${HOME}/.bash_logout"

}

function setup_trap() {

	# Passes the name of the signal as $1 to trap_signals.
	# Which can be very helpful during debugging.

	local TRAP_WRAPPER="trap_signal"
	local FUNCTION="${1}"
	local SIGNALS="${*:2}"

	for SIGNAL in ${SIGNALS};
	do

		if [[ "${DEBUG:-FALSE}" == "TRUE " ]];
		then
			echo "Setting Trap: ${SIGNAL}"
		fi

		# shellcheck disable=SC2064
		trap "${TRAP_WRAPPER} ${FUNCTION} ${SIGNAL^^}" "${SIGNAL^^}" || {
			echo "ERROR setting trap!"
			return 1
		}

	done

	# List traps
	if [[ "${DEBUG:-FALSE}" == "TRUE" ]];
	then
		trap -p
	fi

	return 0

}

function trap_signal() {

	# NOTE:
	#   All trap signals can be found with 'trap -l'
	#   The main ones are;
	#
	#   | Name | Number | Meaning |
	#   | EXIT  | 0  | Not really a signal. In bash, run on any exit. In other POSIX shells runs when the shell process exits. |
	#   | HUP   | 1  | Hang Up. The controlling terminal has gone away. |
	#   | INT   | 2  | Interrupt. The user has pressed the interrupt key. |
	#   | QUIT  | 3  | Quit. The user has pressed the quit key. |
	#   | ABORT | 6  | Abort |
	#   | KILL  | 9  | Kill. This signal cannot be caught or ignored. |
	#   | ALRM  | 14 | Alarm Clock. |
	#   | TERM  | 15 | Terminate. This is the default signal sent by the kill command. |

	echo -e "\n"

	if [[ ${1-} ]];
	then
		FUNCTION="$1"
		#echo "Received Function: ${FUNCTION}"
	else
		echo "ERROR: Please provide the Function as \$2"
		return 1
	fi
 
	if [[ ${2-} ]];
	then
		SIGNAL="$2"
		#echo "Received Signal: ${SIGNAL}"
	else
		echo "ERROR: Please provide the Signal as \$1"
		return 1
	fi

	echo "${SIGNAL} received, triggering trap ${FUNCTION}"
	"${FUNCTION}"

	return 0

}

function enter_the_matrix() {

	local MATRIX_LINES
	local MATRIX_COLS
	local MATRIX_TYPE
	local MATRIX_LETTERS

	clear

	if [[ "${1:-EMPTY}" == "EMPTY" ]];
	then
		MATRIX_TYPE="letters"
	else
		MATRIX_TYPE="${1}"
	fi

	case "${MATRIX_TYPE^^}" in

		"LETTERS" )
			MATRIX_MESSAGE="letters"
			MATRIX_LETTERS="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%^&*()"
		;;

		"EMOJI" )
			MATRIX_MESSAGE="emoji"
			MATRIX_LETTERS="🍍🧂🐧💣🔥🚒🧯🧨👍😺😸😹😻😼😽🙀😿😾🍍"
		;;

		* )
			MATRIX_MESSAGE="letters"
			MATRIX_LETTERS="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%^&*()"
		;;

	esac

	# shellcheck disable=SC2154
	echo -e "\nEntering the Matrix of ${MATRIX_MESSAGE}.....\n"

	sleep 2

	MATRIX_LINES=$(tput lines)
	MATRIX_COLS=$(tput cols)

	# shellcheck disable=SC2016
	AWKSCRIPT='
	{

		MATRIX_LETTERS=$1
		MATRIX_LINES=$2
		#XXX=$3
		RANDOM_COL=$4
		CHAR=$5

		LETTER=substr(MATRIX_LETTERS,CHAR,1)

		MATRIX_COLS[RANDOM_COL]=0;

		for (COL in MATRIX_COLS) {

			LINE=MATRIX_COLS[COL];
			MATRIX_COLS[COL]=MATRIX_COLS[COL]+1;

			printf "\033[%s;%sH\033[2;32m%s", LINE, COL, LETTER;
			printf "\033[%s;%sH\033[1;37m%s\033[0;0H", MATRIX_COLS[COL], COL, LETTER;

			if (MATRIX_COLS[COL] >= MATRIX_LINES) {
				MATRIX_COLS[COL]=0;
			}
		}
	}
	'

	echo -e "\e[1;40m"
	clear

	while true
	do

		echo "${MATRIX_LETTERS}" "${MATRIX_LINES}" "${MATRIX_COLS}" $(( RANDOM % MATRIX_COLS )) $(( RANDOM % 72 ))
		sleep 0.05

	done | awk "$AWKSCRIPT"

	return 0

}

function rando_emoji() {

	#https://emojipedia.org/fire/
	EMOJIS=(
		🍍
		🧂
		🐧
		💣
		🔥
		🚒
		🧯
		🧨
		👍
		😺
		😸
		😹
		😻
		😼
		😽
		🙀
		😿
		😾
		🍍
	)

	# selects a random element from the EMOJIS set
	EMOJI="${EMOJIS[$RANDOM % ${#EMOJIS[@]}]}"

	echo "${EMOJI}"

	return 0

}

function success_indicator_status() {

	# Make the status code available across sub-shells
	echo $? > "/tmp/SUCCESS_INDICATOR_${USER}.lock"

	return 0

}

function success_indicator() {

	# Relies on a file /tmp/SUCCESS_INDICATOR being present
	local SUCCESS_INDICATOR

	SUCCESS_INDICATOR=$(cat "/tmp/SUCCESS_INDICATOR_${USER}.lock")

	if [ "${SUCCESS_INDICATOR:=1}" -eq 0 ] ;
	then
		echo "👍"
	else
		echo "💩"
	fi

	return 0

}

function checkLoadLevel() {

	# Gets the load of the local system
	local PERCENT_CPU
	local PERCENT_MEM
	local PAGE_SIZE
	local MEM_FREE
	local MEM_USED
	local MEM_TOTAL

	OS_FAMILY=${OS_FAMILY:=UNKNOWN}
	case "${OS_FAMILY,,}" in

		"linux" )

			PERCENT_CPU=$( LC_ALL=C top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
			PERCENT_MEM=$( free -m | awk '/Mem:/ { printf("%3.1f%%", $3/$2*100) }' )

		;;

		"darwin" )

			PERCENT_CPU=$( ps -A -o %cpu | awk '{ s+=$1 } END { print s "" }' | awk '{printf("%.2f\n", $1)}' )
			# vm_stat displays the same information as Activity Monitor.app
			# you just need to multiply the value you want by page size.

			PAGE_SIZE=$( vm_stat | awk -F' ' '/page size of/{print $8}' )

			# shellcheck disable=SC2034
			MEM_FREE=$(( $(vm_stat | awk -F ' ' '/Pages free/{gsub(/\./, "", $3); print $3}') * PAGE_SIZE / 1048576 ))

			MEM_USED=$(( $(vm_stat | awk -F ' ' '/Pages active/{gsub(/\./, "", $3); print $3}') * PAGE_SIZE / 1048576 ))

			MEM_TOTAL=$(( $(sysctl -n hw.memsize) / 1048576 ))

			PERCENT_MEM="$( echo "scale=2; $MEM_USED*100 / $MEM_TOTAL" | bc )%"

		;;

		* )

			PERCENT_CPU="UNKNOWN OS"
			PERCENT_MEM="UNKNOWN OS"

			writeLog "ERROR" "Unknown OS Family: $OS_FAMILY"

		;;

	esac

	echo "CPU: ${PERCENT_CPU}% MEM: ${PERCENT_MEM}"

	return 0

}

function getTime() {

	# Returns the current time in my specified format
	TZ=Australia/Sydney date +%H:%M:%S

}

function compareVersions() {

	# Takes two semver version numbers and returns the result
	# usage:
	#        compareVersions <versionnr1> <versionnr2>
	#        with format for versions xxx.xxx.xxx
	# returns:
	#          0 if v1 eq v2
	#          1 if v1 > v2
	#          -1 if v1 < v2
	local v1=$1
	local v2=$2
	local v1A v1B v1C
	local v2A v2B v2C
	local RESULT
	local VERSION

	#writeLog "DEBUG" "Comparing versions ${v1} and ${v2}"

	# Split v1 into semver X.X.X
	IFS="." read -r v1A v1B v1C <<< "$v1"

	# Split v2 into semver X.X.X
	IFS="." read -r v2A v2B v2C <<< "$v2"

	#writeLog "DEBUG" "v1A: $v1A v1B: $v1B v1C: $v1C"
	#writeLog "DEBUG" "v2A: $v2A v2B: $v2B v2C: $v2C"

	RESULT="$(( (v1A-v2A)*1000000+(v1B-v2B)*1000+v1C-v2C ))"

	#writeLog "DEBUG" "Compare Versions Result: $RESULT"

	# If v1 < v2
	if [ $RESULT -lt 0 ] ;
	then

		VERSION="-1"

	# If v1 = v2
	elif [  $RESULT -eq 0 ] ;
	then

		VERSION="0"

	# If v1 > v2
	else

		VERSION="1"

	fi

	echo "${VERSION:-99}"

	return 0

}

function addPath() {

	# Add all the provided directories to the path

	local FOLDER="${1}"

	if [ -d "${FOLDER}" ];
	then

		 # Don't duplicate folders already in the path
		if ! grep -E "${FOLDER}:" <<<"${PATH}" >/dev/null ;
		then

			export PATH=${FOLDER}:$PATH
			writeLog "DEBUG" "Added $FOLDER to the Path"

		else

			writeLog "DEBUG" "Folder $FOLDER already in the Path"

		fi

	else

		writeLog "ERROR" "Folder $FOLDER doesn't exist"

	fi

}

function checkResult() {

	local RESULT=$1

	if [[ $RESULT -ne 0 ]];
	then
		return 1
	else
		return 0
	fi

}

function checkBin() {

	# Checks the binary name is available in the path

	local COMMAND="$1"

	#if ( command -v "${COMMAND}" 1> /dev/null ) ; # command breaks with aliases
	if ( type -P "${COMMAND}" &> /dev/null ) ;
	then
		writeLog "DEBUG" "The command $COMMAND is available in the Path"
		return 0
	else
		writeLog "DEBUG" "The command $COMMAND is not available in the Path"
		return 1
	fi

}

function checkReqs() {

	# Make sure all the required binaries are available within the path
	for BIN in "${REQ_BINS[@]}" ;
	do
		writeLog "DEBUG" "Checking for dependant binary $BIN"
		checkBin "$BIN" || {
			writeLog "ERROR" "Please install the $BIN binary on this system in order to run ${SCRIPT}"
			return 1
		}
	done

	return 0

}

function pimped_prompt() {

	# HOT TIP:
	#   echo -e doesn't understand \[ \]. use \001 and \002
	#   If your text has an escape before a number, there is a bash bug where it will eat one digit!
	#   so use \x01 and \x02 instead!
	# Reference: https://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html"

	PS1="\001$(success_indicator_status)\002"
	if [ "${OS_FAMILY:-EMPTY}" == "darwin" ];
	then
		PS1+="\[$(iterm2_prompt_mark)\]"
	fi
	
	PS1+=" $(rando_emoji) "
	# shellcheck disable=SC2154
	PS1+="${bgCyan}${fgWhite} $(checkLoadLevel) ${bgReset}"
	# shellcheck disable=SC2154
	PS1+="${bgWhite}${fgBlue} $(getTime) ${bgReset}"
	# shellcheck disable=SC2154
	PS1+="${bgMagenta}${fgWhite} \u@\h ${bgReset}"
	PS1+="$(kubePS1)"
	# shellcheck disable=SC2154
	PS1+="${bgRed} $(git_branch) ${bgReset}"
	# shellcheck disable=SC2154
	PS1+="${bgWhite} $(git_status) ${bgReset}"
	# shellcheck disable=SC2154
	PS1+="${bgGreen} \W ${bgReset}"
	PS1+=" $(success_indicator) "
	PS1+="$ "

	if [[ "${FLATPAK_ID:-EMPTY}" == "com.visualstudio.code" ]];
	then
		
		# If inside the vscode flatpak
		writeLog "DEBUG" "Flatpak environment detected"
		export PS1="[Flatpak: \u@\h \W]\\$ "
	
	elif [[ "${VARIANT:-EMPTY}" == "Silverblue" ]];
	then
		
		# If on the Silverblue Host
		writeLog "DEBUG" "Silverblue environment detected"
		export PS1="[Silverblue: \u@\h \W]\\$ "
	
	elif [[ "${VARIANT:-EMPTY}" == "Container Image" ]];
	then
	
		# If inside a toolbox container
		writeLog "DEBUG" "Container environment detected"
		#export PS1="[Silverblue: \u@\h \W]\\$ "
	
	fi

}

function locale_generate() {

		local LOCALE_GEN_FILE="/etc/locale.gen"
		# shellcheck disable=SC2034
		local LANG_FRONT=${LANG%.*}
		# shellcheck disable=SC2034
		local LANG_BACK=${LANG#*.}

		if [[ -f "${LOCALE_GEN_FILE}" ]];
		then

				# Does a change need to be made
				if grep -E -q "^# ${LANG} ${LANGUAGE_BACK}" "${LOCALE_GEN_FILE}" ;
				then

						writeLog "INFO" "Reconfiguring locale to ${LANG}"

						sudo sed -i "s/^# $LANG $LANG_BACK/$LANG $LANG_BACK/g" "${LOCALE_GEN_FILE}" || return 1

						if ! checkBin locale-gen;
						then
								sudo apt-get install --yes locales locales-all
						fi

						sudo locale-gen "${LANGUAGE}" || { writeLog "ERROR" "Failed to rune locale-gen" ; return 1 ; }

						sudo update-locale LANG="${LANG}" || { writeLog "ERROR" "Failed to run update-locale" ; return 1 ; }

				fi

		else

				writeLog "DEBUG" "No locale gen file present at ${LOCALE_GEN_FILE}"

		fi

		return 0

}

function showMemUsage() {

		# I can never remember the ps syntax :/

		local NUM="$1"

		# Show top 10 process by memory
		ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head -n "${NUM:-10}"

		return 0

}

#########################
# Exports
#########################

export -f setup_trap trap_signal
