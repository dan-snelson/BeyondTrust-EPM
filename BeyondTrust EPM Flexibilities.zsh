#!/bin/zsh --no-rcs 
# shellcheck shell=bash

####################################################################################################
#
# BeyondTrust Endpoint Privilege Management Flexibilities
#
# Assign a computer to High, Medium or Low Flexibility via a Jamf Pro Script Parameter
#
####################################################################################################
#
# HISTORY
#
#   Version 0.0.1, 08-Jul-2024, Dan K. Snelson (@dan-snelson)
#   - Original version
#
#   Version 0.0.2, 09-Jul-2024, Dan K. Snelson (@dan-snelson)
#   - Re-Validate Groups pre-exit
#
#   Version 0.0.3, 15-Jul-2024, Dan K. Snelson (@dan-snelson)
#   - `highestGID` now looks for highest GID below 500
#
#   Version 0.0.4, 16-Jul-2024, Dan K. Snelson (@dan-snelson)
#   - Bounce processes pre-exit if caching is enabled
#
####################################################################################################



####################################################################################################
#
# Global Variables
#
####################################################################################################

export PATH=/usr/bin:/bin:/usr/sbin:/sbin

# Script Version
scriptVersion="0.0.4"

# Client-side Log
scriptLog="/var/log/org.churchofjesuschrist.log"

# Last Logged-in User
lastUser=$( defaults read /Library/Preferences/com.apple.loginwindow.plist lastUserName )

# BeyondTrust EPM Caching Status
cachingStatus=$( /usr/local/bin/pmfm status | grep "Cache enabled: true" )



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Jamf Pro Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Parameter 4: BeyondTrust Endpoint Privilege Management Flexibility [ Low (default) | Medium | High ]
btEPMflexibility="${4:-"low"}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Organization Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Script Human-readabale Name
humanReadableScriptName="BeyondTrust Endpoint Privilege Management Flexibilities"

# Organization's Script Name
organizationScriptName="BT-EPM-F"

# Organization's Group Names
# (GIDs are automatically assigned, based on the next three highest available numbers)
btEPMhighGroupName="bt_epm_flexibility_high"
btEPMmediumGroupName="bt_epm_flexibility_medium"
btEPMlowGroupName="bt_epm_flexibility_low"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Group Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

highestGID=$( dscl . list /Groups PrimaryGroupID | tr -s ' ' | sort -n -t ' ' -k2,2 | awk '$2 < 500 {print $2}' | tail -n 1 )
btEPMhighGID=$(( highestGID + 1 ))
btEPMmediumGID=$(( highestGID + 2 ))
btEPMlowGID=$(( highestGID + 3 ))



####################################################################################################
#
# Functions
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Client-side Logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateScriptLog() {
    echo "${organizationScriptName} ($scriptVersion): $( date +%Y-%m-%d\ %H:%M:%S ) - ${1}" | tee -a "${scriptLog}"
}

function preFlight() {
    updateScriptLog "[PRE-FLIGHT]      ${1}"
}

function logComment() {
    updateScriptLog "                  ${1}"
}

function notice() {
    updateScriptLog "[NOTICE]          ${1}"
}

function info() {
    updateScriptLog "[INFO]            ${1}"
}

function debugVerbose() {
    if [[ "$debugMode" == "verbose" ]]; then
        updateScriptLog "[DEBUG VERBOSE]   ${1}"
    fi
}

function debug() {
    if [[ "$debugMode" == "true" ]]; then
        updateScriptLog "[DEBUG]           ${1}"
    fi
}

function errorOut(){
    updateScriptLog "[ERROR]           ${1}"
}

function error() {
    updateScriptLog "[ERROR]           ${1}"
    let errorCount++
}

function warning() {
    updateScriptLog "[WARNING]         ${1}"
    let errorCount++
}

function fatal() {
    updateScriptLog "[FATAL ERROR]     ${1}"
    exit 1
}

function quitOut(){
    updateScriptLog "[QUIT]            ${1}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate / Create Groups
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function validateCreateGroup(){

    groupName="${1}"
    groupNumber="${2}"

    if [[ $( dscl . list /Groups | grep "${groupName}" ) ]]; then

        logComment "${groupName} Exists: $( dscl . -read Groups/"${groupName}" GroupMembership 2>&1)"

    else

        notice "Creating ${groupName} …"
        dscl . create /Groups/"${groupName}"
        if [[ $? -ne 0 ]]; then
            fatal "Failed to create ${groupName}"
        else
            logComment "Successfully created ${groupName}"
        fi

        notice "Assigning ${groupName} a GID of ${groupNumber} …"
        dscl . create /Groups/"${groupName}" gid "${groupNumber}"
        if [[ $? -ne 0 ]]; then
            fatal "Failed to assign ${groupName} a GID of ${groupNumber}"
        else
            logComment "Successfully assigned ${groupName} a GID of ${groupNumber}"
        fi

    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Add User to Group
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function addUserToGroup(){

    groupName="${1}"

    notice "Add ${lastUser} to ${groupName} …"

    membershipCheck=$( dseditgroup -o checkmember -m "${lastUser}" "${groupName}" )

    if [[ "${membershipCheck}" == *"NOT a member"* ]]; then

        logComment "Adding ${lastUser} to ${groupName} …"
        dseditgroup -o edit -a "${lastUser}" -t user "${groupName}"
        if [[ $? -ne 0 ]]; then
            fatal "Failed to adding ${lastUser} to ${groupName}; exiting"
        else
            membershipCheck=$( dseditgroup -o checkmember -m "${lastUser}" "${groupName}" )
            logComment "${membershipCheck}"
        fi
    
    else

        logComment "${membershipCheck}"

    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Remove User from Group
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function removeUserFromGroup(){

    groupName="${1}"

    notice "Remove ${lastUser} from ${groupName} …"

    membershipCheck=$( dseditgroup -o checkmember -m "${lastUser}" "${groupName}" )

    if [[ "${membershipCheck}" == *"is a member"* ]]; then

        logComment "Removing ${lastUser} from ${groupName} …"
        dseditgroup -o edit -d "${lastUser}" -t user "${groupName}"
        if [[ $? -ne 0 ]]; then
            fatal "Failed to remove ${lastUser} from ${groupName}; exiting"
        else
            membershipCheck=$( dseditgroup -o checkmember -m "${lastUser}" "${groupName}" )
            logComment "${membershipCheck}"
        fi
    
    else

        logComment "${membershipCheck}"

    fi

}



####################################################################################################
#
# Pre-flight Checks
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Client-side Logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ! -f "${scriptLog}" ]]; then
    touch "${scriptLog}"
    if [[ -f "${scriptLog}" ]]; then
        preFlight "Created specified scriptLog: ${scriptLog}"
    else
        fatal "Unable to create specified scriptLog '${scriptLog}'; exiting.\n\n(Is this script running as 'root' ?)"
    fi
else
    preFlight "Specified scriptLog '${scriptLog}' exists; writing log entries to it"
fi




# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Logging Preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

preFlight "\n\n###\n# $humanReadableScriptName (${scriptVersion})\n# Assigning Flexibility: ${btEPMflexibility}\n###\n"
preFlight "Initiating …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
    fatal "This script must be run as root; exiting."
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Complete
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

preFlight "Complete!"



####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate Last Logged-in User
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -z "${lastUser}" ]]; then
    fatal "No logins; exiting."
else
    notice "Last User: ${lastUser}; proceeding …"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate / Create Groups
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

notice "Validate / Create Groups"
validateCreateGroup "${btEPMhighGroupName}" "${btEPMhighGID}"
validateCreateGroup "${btEPMmediumGroupName}" "${btEPMmediumGID}"
validateCreateGroup "${btEPMlowGroupName}" "${btEPMlowGID}"

# Output Group Names and GIDs (based on the first 10 characters of $btEPMhighGroupName)
dscl . list /Groups PrimaryGroupID | grep "${btEPMhighGroupName:0:10}" | sort | tee -a "${scriptLog}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Add / Remove User from Groups
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

case ${btEPMflexibility} in

    "High" | "high" )
        notice "Adding ${lastUser} to High Flexibility …"
        addUserToGroup "${btEPMhighGroupName}"
        removeUserFromGroup "${btEPMmediumGroupName}"
        removeUserFromGroup "${btEPMlowGroupName}"
        ;;

    "Medium" | "medium" )
        notice "Adding ${lastUser} to Medium Flexibility …"
        removeUserFromGroup "${btEPMhighGroupName}"
        addUserToGroup "${btEPMmediumGroupName}"
        removeUserFromGroup "${btEPMlowGroupName}"
        ;;

    "Low" | "low" )
        notice "Adding ${lastUser} to Low Flexibility …"
        removeUserFromGroup "${btEPMhighGroupName}"
        removeUserFromGroup "${btEPMmediumGroupName}"
        addUserToGroup "${btEPMlowGroupName}"
        ;;

    * )
        warning "Unrecognized value for Parameter 4: BeyondTrust Endpoint Privilege Management Flexibility: ${btEPMflexibility}"
        notice "Adding ${lastUser} to Low Flexibility …"
        removeUserFromGroup "${btEPMhighGroupName}"
        removeUserFromGroup "${btEPMmediumGroupName}"
        addUserToGroup "${btEPMlowGroupName}"
        ;;

esac



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Re-Validate Groups
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

notice "Re-Validate Groups"
validateCreateGroup "${btEPMhighGroupName}" "${btEPMhighGID}"
validateCreateGroup "${btEPMmediumGroupName}" "${btEPMmediumGID}"
validateCreateGroup "${btEPMlowGroupName}" "${btEPMlowGID}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Bounce processes if caching is enabled
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -n "${cachingStatus}" ]]; then
    notice "Caching enabled; bounce processes …"
    killall -v defendpointd | tee -a "${scriptLog}"
    killall -v Custodian | tee -a "${scriptLog}"
else
    logComment "Caching disabled"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Exit
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

notice "Shine on, you crazy diamonds!"

exit 0