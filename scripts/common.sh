#!/usr/bin/env bash

#########################
# Name: common.sh
# Description: Common functions.
#########################

function pause() {

	local MESSAGE=$1

	read -p "${MESSAGE}"

	return 0

}

function detectOS() {

        OS_FAMILY="${OS_FAMILY:=UNKNOWN}"
        OS_NAME="${OS_NAME:=UNKNOWN}"
        OS_VER="${OS_VER:=UNKNOWN}"
        OS_LAYER="${OS_LAYER:=UNKNOWN}"

    writeLog "DEBUG" "Determining the OS Name and Version"

        OS_FAMILY=$(uname)

        if [[ -f /etc/os-release ]];
        then

                # freedesktop.org and systemd
                . /etc/os-release
                OS_NAME=$ID
                OS_VER=$VERSION_ID

        elif type lsb_release >/dev/null 2>&1;
        then

                # linuxbase.org
                OS_NAME=$(lsb_release -si)
                OS_VER=$(lsb_release -sr)

        elif [[ -f /etc/lsb-release ]];
        then

                # For some versions of Debian/Ubuntu without lsb_release command
                . /etc/lsb-release
                OS_NAME=$DISTRIB_ID
                OS_VER=$DISTRIB_RELEASE

        elif [[ -f /etc/debian_version ]];
        then

                # Older Debian/Ubuntu/etc.
                OS_NAME=Debian
                OS_VER=$(cat /etc/debian_version)

        elif [[ -f /etc/SuSe-release ]];
        then

                # Older SuSE/etc.
                OS_NAME=$(head -n 1 /etc/SuSE-release)
                OS_VER=$(sed -n 2p /etc/SuSE-release | cut -f2 -d'=' | tr -d '[:space:]')

        elif [[ -f /etc/redhat-release ]];
        then

                # Older Red Hat, CentOS, etc.
                OS_NAME=$(cat /etc/redhat-release)
                OS_VER="Old Release"

        else

                # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
                OS_NAME=$(uname -s)
                OS_VER=$(uname -r)

        fi

        # Determine if the OS is running on one of the non-standard setups like WSL, ChromeOS or Silverblue

        if egrep -qi "microsoft|wsl" /proc/version ;
        then

                OS_LAYER="WSL"

        elif egrep -qi "chromium" /proc/version ;
        then

                OS_LAYER="Crostini"

        elif [[ -f /etc/os-release ]];
        then

                . /etc/os-release
                OS_LAYER="${VARIANT_ID:=UNKNOWN}"

        fi

        if [[ "${OS_LAYER:-UNKNOWN}" == "UNKNOWN" ]];
        then
                writeLog "DEBUG" "Operating System: ${OS_FAMILY} ${OS_NAME} ${OS_VER}"
        else
                OS_LAYER="${OS_LAYER,,}"
                writeLog "DEBUG" "Operating System: ${OS_FAMILY} ${OS_NAME} ${OS_VER} running on ${OS_LAYER}"
        fi

        export OS_FAMILY
        export OS_NAME
        export OS_VER
        export OS_LAYER

        return 0

}

function checkLog() {

    # Ensures that the provided log file exists or sets a default.
    # Will create the parent directories if required.

    local FILE="${1}"

    # Set a default log file location if not specified
    if [[ "${FILE:-EMPTY}" == "EMPTY" ]];
    then
        echo "WARNING: checkLog function was not passed a log location, setting default to be in /tmp"
        FILE="/tmp/${SCRIPT:-unknown}.log"
        export LOG_FILE=${FILE}
    fi

    # Does the parent directory for the log file exist?
    PARENT=$(dirname "${FILE}")
    if [[ ! -d "${PARENT}" ]];
    then

        if [[ "${LOG_LEVEL}" == "DEBUG" ]];
        then
            echo "DEBUG: Creating new log file parent directory ${PARENT}"
        fi

        mkdir -p "${PARENT}"
        checkResult $? || { echo "ERROR: Failed to create log directory" ; return 1 ; }

    fi

    if [[ ! -f "${FILE}" ]];
    then

        touch "${FILE}" || {
            echo "ERROR: Failed to create logfile ${FILE}"
            return 1
        }

    fi

    return 0

}

function checkLogLevel() {

    # The log level should be globally defined in bashrc or will default to INFO.

    # Only the following log levels are supported.
    #   DEBUG
    #   INFO or INFORMATION
    #   WARN or WARNING
    #   ERR or ERROR

    local LEVEL="${1}"

    LEVEL="${LEVEL:=INFO}"      # Default to info if not present.
    LEVEL=$(echo "${LEVEL}" | tr '[:lower:]' '[:upper:]' )

    case "${LEVEL}" in

        "DEBUG" | "TRACE" )
            LOG_LEVEL="DEBUG"
        ;;

        "INFO" | "INFORMATION" )
            LOG_LEVEL="INFO"
        ;;

        "WARN" | "WARNING" )
            LOG_LEVEL="WARN"
        ;;

        "ERR" | "ERROR" )
            LOG_LEVEL="ERR"
        ;;

        * )
            LOG_LEVEL="INFO"
        ;;

    esac

    export LOG_LEVEL

    return 0

}

function writeLog() {

    local LEVEL=$1                      # The log level; DEBUG,INFO,WARN,ERROR
    local MESSAGE=$2                    # The log message
    local DESTINATION                   # The log destination; stdout, file, all
    local APPEND                        # Boolean whether to append exsting log file.

    ###############
    # Checks
    ###############

    # The log level should be previously defined or defaults to INFO
    checkLogLevel "${LOG_LEVEL}" || {
        echo "Failed to check the global log level!"
        return 1
    }

    # The level provided cannot be empty.
    if [[ "${LEVEL:-EMPTY}" == "EMPTY" ]];
    then
        echo "Please provide a Log Level as \$1"
        return 1
    else
        LEVEL=$(echo "${LEVEL}" | tr '[:lower:]' '[:upper:]' )
    fi

    # The message provided cannot be empty.
    if [[ "${MESSAGE:-EMPTY}" == "EMPTY" ]];
    then
        echo "Please provide a Log Message as \$2"
        return 1
    fi

    ###############
    # Level
    ###############

    case "${LEVEL}" in

        "START" | "FRESH" | "NEW" | "CREATE" )

            LEVEL="INFO"
            APPEND="FALSE"

        ;;

        "DEBUG" | "TRACE" )

            LEVEL="DEBUG"
            APPEND="TRUE"

            # Do not show debug messages if the level is > debug
            if [[ ! "${LEVEL}" == "${LOG_LEVEL}" ]] ;
            then
                return 0
            fi

        ;;

        "INFO" | "INFORMATION" )

            LEVEL="INFO"
            APPEND="TRUE"

            # Do not show info messages if the level is > info
            if [[ "${LOG_LEVEL}" == "WARN" ]] || [[ "${LOG_LEVEL}" == "ERR" ]] ;
            then
                return 0
            fi

        ;;

        "WARN" | "WARNING" )

            LEVEL="WARN"
            APPEND="TRUE"

            # Do not show warning messages if the level is error.
            if [[ "${LOG_LEVEL}" == "ERR" ]] ;
            then
                return 0
            fi

        ;;

        "ERR" | "ERROR" )

            LEVEL="ERR"
            APPEND="TRUE"

           # Errors are always shown

        ;;

        * )

            LEVEL="ERR"
            APPEND="TRUE"

            # Show a message to the user.
            MESSAGE="Unknown log level $LEVEL provided to log function. Valid level options are DEBUG, INFO, WARN, ERR, START"

        ;;

    esac

    ###############
    # Destination
    ###############

    LOG_MESSAGE="$( date +"%Y/%m/%d %H:%M:%S" ) [$LEVEL] ${MESSAGE}"

    # Where are we sending logs?
    # Defaults to stdout unless globally defined
    #   stdout = stdout only
    #   file = file only
    #   all = both stdout and file
    DESTINATION="${LOG_DESTINATION:=stdout}"
    DESTINATION=$(echo "${DESTINATION}" | tr '[:lower:]' '[:upper:]' )

    case "${DESTINATION}" in

        "STDOUT" )

            echo -e "$( date +"%Y/%m/%d %H:%M:%S" ) [$LEVEL] $MESSAGE"

        ;;

        "FILE" )

            checkLog "${LOG_FILE}" || {
                echo "Failed to check the log file at ${LOG_FILE}"
                return 1
            }

            if [[ "${APPEND:-TRUE}" == "TRUE" ]];
            then
                echo -e "$( date +"%Y/%m/%d %H:%M:%S" ) [$LEVEL] $MESSAGE" >> "${LOG_FILE}"
            else
                echo -e "$( date +"%Y/%m/%d %H:%M:%S" ) [$LEVEL] $MESSAGE" > "${LOG_FILE}"
            fi

        ;;

        "ALL" | "BOTH" )

            checkLog "${LOG_FILE}" || {
                echo "Failed to check the log file at ${LOG_FILE}"
                return 1
            }

            if [[ "${APPEND:-TRUE}" == "TRUE" ]];
            then
                echo -e "$( date +"%Y/%m/%d %H:%M:%S" ) [$LEVEL] $MESSAGE" | tee --append "${LOG_FILE}"
            else
                echo -e "$( date +"%Y/%m/%d %H:%M:%S" ) [$LEVEL] $MESSAGE" | tee "${LOG_FILE}"
            fi

        ;;

        * )

            echo "Unknown Logging destination ${DESTINATION:-EMPTY}, defaulting to stdout"
            echo -e "$( date +"%Y/%m/%d %H:%M:%S" ) [$LEVEL] $MESSAGE"

        ;;

    esac

    return 0

}

#########################
# Exported Functions
#########################

export -f checkLog
export -f checkLogLevel
export -f detectOS
export -f pause
export -f writeLog
