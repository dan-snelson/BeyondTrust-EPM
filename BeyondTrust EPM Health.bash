#!/bin/bash
####################################################################################################
#
# ABOUT
#
#   BeyondTrust EPM Health
#
#   A Jamf Pro Extension Attribute which determines the health of BeyondTrust Privilege Management for Mac
# 
#   If the `targetPolicy` is not found, "Not Installed" will be returned.
# 
#   If the `targetPolicy` is found, the following is returned:
# 
#   - Policy
#       - Name
#       - Revision Number
#   - System Extension
#   - Process Status
#       - defendpointd
#       - Custodian
#       - PMCAdapter
#
####################################################################################################
#
# HISTORY
#
#   Version 0.0.1, 22-Nov-2023, Dan K. Snelson (@dan-snelson)
#       Original version
#
#   Version 0.0.2, 25-Nov-2023, Dan K. Snelson (@dan-snelson)
#       Added Tom Ziegmann-inspired racing-stripes
#
#   Version 0.0.3, 27-Nov-2023, Dan K. Snelson (@dan-snelson)
#       Added Andrew Spokes-inspired racing-stripe
#       Added System Extension check
#
#    Version 0.0.4, 28-Nov-2023, Dan K. Snelson (@dan-snelson)
#       Added Eric Hemmeter-inspired racing-stripe
#       Output edits (i.e., removed "Policy:")
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

scriptVersion="0.0.4"
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin/
targetPolicy="/etc/defendpoint/ic3.xml"



####################################################################################################
#
# Functions
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for running processes (supplied as Parameter 1)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function procesStatus() {

    processToCheck="${1}"

    status=$( /usr/bin/pgrep -x "${processToCheck}" )
    if [[ -n ${status} ]]; then
        processCheckResult+="'${processToCheck}' running; "
    else
        processCheckResult+="'${processToCheck}' NOT running; "
    fi

}



####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate Presence of Target Policy
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -f "${targetPolicy}" ]] ; then

    # Validate BT PMfM System Extension
    systemExtensionTest=$( systemextensionsctl list | awk -F"[][]" '/com.beyondtrust.endpointsecurity/ {print $2}' )

    # Capture BT PMfM Policy Name and Revision
    policyName=$( xmllint --xpath "string(//@PolicyName)" "${targetPolicy}" )
    policyRevision=$( xmllint --xpath "string(//@RevisionNumber)" "${targetPolicy}" )

    # Validate various BT PMfM Processes
    procesStatus "defendpointd"
    procesStatus "Custodian"
    procesStatus "PMCAdapter"
    procesStatus "PMCPackageManager"
	# procesStatus "PrivilegeManagement"     	# Appears to only run if a user is logged-in
	# procesStatus "NewPrivilegeManagement"     # Appears to only run if a user is logged-in

    # Remove trailing "; "
    processCheckResult=${processCheckResult/%; }

    RESULT="${policyName} (r${policyRevision}); System Extension: ${systemExtensionTest}; ${processCheckResult}"

else

    RESULT="Not Installed"

fi

echo "<result>${RESULT}</result>"

exit 0