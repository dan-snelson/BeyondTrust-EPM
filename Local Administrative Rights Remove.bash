#!/bin/bash
####################################################################################################
#
# ABOUT
#
#   Removes admin rights from adminstrators NOT specificially listed in `approvedAdmins`
#
####################################################################################################
#
# HISTORY
#
#   Version 1.0.0, 08-May-2023, Dan K. Snelson (@dan-snelson)
#       Original version
#
#   Version 2.0.0, 20-May-2023, Dan K. Snelson (@dan-snelson)
#       Confirm BeyondTrust Privilege Access Management for macOS services are running before
#       removing local admin rights
#
#   Version 2.0.1, 10-Nov-2023, Dan K. Snelson (@dan-snelson)
#       - When no users are logged in, only check for two (2) BT PMfM services
#       - Check that `dseditgroup` succeeded
#
#   Version 2.0.2, 25-Nov-2023, Dan K. Snelson (@dan-snelson)
#       - Added check for PMCAdapter
#
#   Version 2.0.3, 20-May-2024, Dan K. Snelson (@dan-snelson)
#       - Changed $adminMemberCheck to leverage `dseditgroup checkmember`
#
#   Version 2.0.4, 07-Jun-2024, Dan K. Snelson (@dan-snelson)
#       - Commented-out check for "PMCAdapter" in favor of check for "PMCPackageManager"
#
####################################################################################################



####################################################################################################
#
# Global Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Script Version and Jamf Pro Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

scriptVersion="2.0.4"
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
scriptLog="${4:-"/var/log/org.churchofjesuschrist.log"}"    # Parameter 4: Script Log Location
approvedAdmins=(root _avectodaemon yourLocalAdmin)          # Space-delimited list of approved local admins
currentAdminUsers=$( /usr/bin/dscl . -read Groups/admin GroupMembership | /usr/bin/cut -c 18- )
currentAdminArray=("$currentAdminUsers")
adminRemovalFailures=""



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
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Client-side Script Logging Function
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateScriptLog() {
    echo -e "$( date +%Y-%m-%d\ %H:%M:%S ) - ${1}" | tee -a "${scriptLog}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Logging Preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "\n\n###\n# Local Administrative Rights Remove (${scriptVersion})\n###\n"
updateScriptLog "PRE-FLIGHT CHECK: Initiating …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
    updateScriptLog "PRE-FLIGHT CHECK: This script must be run as root; exiting."
    exit 1
else
    updateScriptLog "PRE-FLIGHT CHECK: Complete"
fi



####################################################################################################
#
# Functions
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Current Logged-in User Function
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function currentLoggedInUser() {
    loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
    updateScriptLog "Current Logged-in User: ${loggedInUser}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for running processes (supplied as Parameter 1)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function procesStatus() {

    processToCheck="${1}"

    status=$( /usr/bin/pgrep -x "${processToCheck}" )
    if [[ -n ${status} ]]; then
        RESULT+="'${processToCheck}' running; "
    else
        RESULT+="'${processToCheck}' NOT running; "
    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Remove unapproved admins
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function adminRemove() {

    adminAccountToCheck="${1}"

    if [[ " ${approvedAdmins[*]} " =~ " ${adminAccountToCheck} " ]]; then
        updateScriptLog "Not changing approved admin '${adminAccountToCheck}'."
    else
        dseditgroup -o edit -d "${adminAccountToCheck}" -t user admin
        if [[ $? = 0 ]]; then updateScriptLog "Attempted to remove user '${adminAccountToCheck}' from admin group."; fi
    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for approved admins only
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function adminCheck() {

    standardAccountToCheck="${1}"

    if [[ " ${approvedAdmins[*]} " =~ " ${standardAccountToCheck} " ]]; then
        updateScriptLog "Approved admin '${standardAccountToCheck}' unchanged."
    else
        # adminMemberCheck=$( dsmemberutil checkmembership -U "${standardAccountToCheck}" -G admin )
        adminMemberCheck=$( dseditgroup -o checkmember -m "${standardAccountToCheck}" admin )
        updateScriptLog "Unapproved admin '${standardAccountToCheck}' unchanged."
        updateScriptLog "'${standardAccountToCheck}' ${adminMemberCheck} 'admin'."
        adminRemovalFailures+="${standardAccountToCheck} "
    fi
}



####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for BeyondTrust Privilege Access Management for macOS services
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

currentLoggedInUser

# Validate various BT PMfM Processes
procesStatus "defendpointd"
procesStatus "Custodian"
# procesStatus "PMCAdapter"
procesStatus "PMCPackageManager"
procesStatus "PrivilegeManagement"
procesStatus "NewPrivilegeManagement"

updateScriptLog "Status: ${RESULT}"

case ${RESULT} in

    *"NOT"* )
        updateScriptLog "At least one service isn't running; exiting …"
        exit 1
        ;;
    * )
        updateScriptLog "All services running; proceeding …"
        ;;

esac



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Remove Local Administrative Rights
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "\n\nAttempting to remove unapproved admins …"

for currentAdminAccount in ${currentAdminArray[@]}; do
    adminRemove "${currentAdminAccount}"
done



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check Local Administrative Rights
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

updateScriptLog "\n\nChecking for unapproved admins …"

updatedAdminUsers=$( /usr/bin/dscl . -read Groups/admin GroupMembership | /usr/bin/cut -c 18- )
updatedAdminArray=("$updatedAdminUsers")

for updatedAdminAccount in ${updatedAdminArray[@]}; do
    adminCheck "${updatedAdminAccount}"
done



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Exit
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -n "${adminRemovalFailures}" ]]; then
    updateScriptLog "\n\nERROR: Unapproved admin: ${adminRemovalFailures}"
    exit 1
else
    updateScriptLog "\n\nSuccess! No unapproved admins."
    exit 0
fi