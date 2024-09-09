#!/bin/zsh --no-rcs 
# shellcheck shell=bash

####################################################################################################
#
# BeyondTrust EPM Inspector
#
#   Purpose: Displays an end-user message about BeyondTrust EPM via swiftDialog
#
####################################################################################################
#
# HISTORY
#
# Version 0.0.1, 16-Jul-2024, Dan K. Snelson (@dan-snelson)
#   - Original, proof-of-concept version
#   - Based on: https://snelson.us/2023/04/crowdstrike-falcon-inspector-0-0-2-with-swiftdialog/
#
# Version 0.0.2, 17-Jul-2024, Dan K. Snelson (@dan-snelson)
#   - Added `progressSteps` variable
#   - Included macOS version
#
# Version 0.0.3, 17-Jul-2024, Dan K. Snelson (@dan-snelson)
#   - Output MDM Overrides to scriptLog
#
# Version 0.0.4, 17-Jul-2024, Dan K. Snelson (@dan-snelson)
#   - Changed `debugMode` to more robust `operationMode`
#
# Version 0.0.5, 18-Jul-2024, Dan K. Snelson (@dan-snelson)
#   - Added output for the BeyondTrust PMC Server URL
#   - Output 'defendpoint.plist' to ${scriptLog} (in "verbose" Operation Mode)
#
# Version 0.0.6, 29-Jul-2024, Dan K. Snelson (@dan-snelson)
#   - Updates inspired by "CrowdStrike Falcon Inspector"
#
# Version 0.0.7, 22-Aug-2024, Dan K. Snelson (@dan-snelson)
#   - Added checksum validation of "${targetPolicy}"
#   - Stopped incrementing the progress bar like an animal
#
# Version 0.0.8, 22-Aug-2024, Dan K. Snelson (@dan-snelson)
#   - Added "pmfmdiag all" (thanks, @tziegmann!)
#
# Version 0.0.9, 23-Aug-2024, Dan K. Snelson (@dan-snelson)
#   - Added UseSheets status check
#
# Version 0.0.10, 23-Aug-2024, Dan K. Snelson (@dan-snelson)
#   - Added output for assigned flexibility (See: [BeyondTrust PMfM Workstyle.zsh](https://github.com/dan-snelson/BeyondTrust-EPM/blob/main/BeyondTrust%20PMfM%20Workstyle.zsh))
#
# Version 0.0.11, 09-Sep-2024, Dan K. Snelson (@dan-snelson)
#   - Added output for BeyondTrust PMfM Accounts (See: [9. macOS Sequoia 15 and “missing” EPM accounts](https://snelson.us/2024/08/beyondtrust-epm-racing-stripes/#9))
#
####################################################################################################



####################################################################################################
#
# Global Variables
#
####################################################################################################

export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin/

# Script Version
scriptVersion="0.0.11"

# Client-side Log
scriptLog="/var/log/org.churchofjesuschrist.log"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Jamf Pro Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Parameter 4: Operation Mode [ debug | normal | verbose ]
operationMode="${4:-"verbose"}"

# Parameter 5: "Anticipation" Duration (in seconds)
anticipationDuration="${5:-"3"}"

# Parameter 6: Expected Policy Checksum [ $( openssl dgst -sha256 "${targetPolicy}" | awk -F'= ' '{print $2}' ) ]
expectedPolicyChecksum="${6:-"f42199e2af570d41e6143f9095de74c19ebf1a05d0b279accb27ef2c20510b56"}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Organization Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Script Human-readabale Name
humanReadableScriptName="BeyondTrust EPM Inspector"

# Organization's Script Name
organizationScriptName="BT-EPM-I"

# Client-side BeyondTrust EMP Policy
targetPolicy="/etc/defendpoint/ic3.xml"

# Client-side Policy Checksum
clientPolicyChecksum=$( openssl dgst -sha256 "${targetPolicy}" | awk -F'= ' '{print $2}' )



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Operating System, Computer Model Name, etc.
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

osVersion=$( sw_vers -productVersion )
osVersionExtra=$( sw_vers -productVersionExtra ) 
osBuild=$( sw_vers -buildVersion )
osMajorVersion=$( echo "${osVersion}" | awk -F '.' '{print $1}' )
if [[ -n $osVersionExtra ]] && [[ "${osMajorVersion}" -ge 13 ]]; then osVersion="${osVersion} ${osVersionExtra}"; fi # Report RSR sub version if applicable



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Logged-in User Variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
loggedInUserFullname=$( id -F "${loggedInUser}" )
loggedInUserFirstname=$( echo "$loggedInUserFullname" | sed -E 's/^.*, // ; s/([^ ]*).*/\1/' | sed 's/\(.\{25\}\).*/\1…/' | awk '{print ( $0 == toupper($0) ? toupper(substr($0,1,1))substr(tolower($0),2) : toupper(substr($0,1,1))substr($0,2) )}' )
loggedInUserID=$( id -u "${loggedInUser}" )
loggedInUserGroupMembership=$( id -Gn "${loggedInUser}" )



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# UseSheets Status
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

useSheetStatus=$( defaults read "/Users/${loggedInUser}/Library/Preferences/com.apple.Preferences.plist" UseSheets 2>&1 )
if [[ "${useSheetStatus}" == "0" ]]; then
    useSheetStatusHumanReadable="passed"
else
    useSheetStatusHumanReadable="failed"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Dialog binary (and enable swiftDialog's `--verbose` mode with script's operationMode)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# swiftDialog Binary Path
dialogBinary="/usr/local/bin/dialog"

# Debug Mode Features
case ${operationMode} in
    "debug" ) dialogBinary="${dialogBinary} --verbose --resizable --debug red" ;;
esac

# swiftDialog Command File
dialogWelcomeLog=$( mktemp /var/tmp/dialogWelcomeLog.XXXX )

# The total number of steps for the progress bar, plus one (i.e., updateWelcomeDialog "progress: increment")
progressSteps="18"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Welcome Dialog Title, Message and Icon
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

title="${humanReadableScriptName} (${scriptVersion})"
message="**Happy $( date +'%A' ), ${loggedInUserFirstname}!**<br><br>This script analyzes the installation of BeyondTrust Endpoint Privilege Management then reports the findings in this window.<br><br>Please wait …"
icon="https://ics.services.jamfcloud.com/icon/hash_a6d0e6852d3319a200e58036039cc69bb09a0882d89e799263c951a632d3a5d2"
# overlayIcon=$( defaults read /Library/Preferences/com.jamfsoftware.jamf.plist self_service_app_path )
button1text="Wait"
infobuttontext="KB8675309"
infobuttonaction="https://servicenow.company.com/support?id=kb_article_view&sysparm_article=${infobuttontext}"
welcomeProgressText="Initializing …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Welcome Dialog Settings and Features
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

dialogWelcome="$dialogBinary \
--title \"$title\" \
--message \"$message\" \
--icon \"$icon\" \
--button1text \"$button1text\" \
--button1disabled \
--infobuttontext \"$infobuttontext\" \
--infobuttonaction \"$infobuttonaction\" \
--progress \"$progressSteps\" \
--progresstext \"$welcomeProgressText\" \
--moveable \
--titlefont size=22 \
--messagefont size=14 \
--iconsize 135 \
--width 650 \
--height 375 \
--commandfile \"$dialogWelcomeLog\" "

# --overlayicon \"$overlayIcon\" \



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

function debug() {
    if [[ "$operationMode" == "debug" ]]; then
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
# Pre-flight Check: Validate / install swiftDialog (Thanks big bunches, @acodega!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function dialogInstall() {

    # Get the URL of the latest PKG From the Dialog GitHub repo
    dialogURL=$(curl -L --silent --fail "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")

    # Expected Team ID of the downloaded PKG
    expectedDialogTeamID="PWA5E9TQ59"

    preFlight "Installing swiftDialog..."

    # Create temporary working directory
    workDirectory=$( /usr/bin/basename "$0" )
    tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )

    # Download the installer package
    /usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"

    # Verify the download
    teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')

    # Install the package if Team ID validates
    if [[ "$expectedDialogTeamID" == "$teamID" ]]; then

        /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
        sleep 2
        dialogVersion=$( /usr/local/bin/dialog --version )
        preFlight "swiftDialog version ${dialogVersion} installed; proceeding..."

    else

        # Display a so-called "simple" dialog if Team ID fails to validate
        osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "Setup Your Mac: Error" buttons {"Close"} with icon caution'
        completionActionOption="Quit"
        exitCode="1"
        quitScript

    fi

    # Remove the temporary working directory when done
    /bin/rm -Rf "$tempDirectory"

}



function dialogCheck() {

    # Output Line Number in `verbose` Debug Mode
    if [[ "${operationMode}" == "debug" ]]; then preFlight "# # # VERBOSE DEBUG MODE: Line No. ${LINENO} # # #" ; fi

    # Check for Dialog and install if not found
    if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then

        preFlight "swiftDialog not found. Installing..."
        dialogInstall

    else

        dialogVersion=$(/usr/local/bin/dialog --version)
        if [[ "${dialogVersion}" < "${swiftDialogMinimumRequiredVersion}" ]]; then
            
            preFlight "swiftDialog version ${dialogVersion} found but swiftDialog ${swiftDialogMinimumRequiredVersion} or newer is required; updating..."
            dialogInstall
            
        else

        preFlight "swiftDialog version ${dialogVersion} found; proceeding..."

        fi
    
    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Quit Script (thanks, @bartreadon!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function quitScript() {

    quitOut "Quitting …"
    updateWelcomeDialog "quit: "

    sleep 1
    quitOut "Exiting …"

    # Remove dialogWelcomeLog
    if [[ -e ${dialogWelcomeLog} ]]; then
        quitOut "Removing ${dialogWelcomeLog} …"
        rm "${dialogWelcomeLog}"
    fi

    quitOut "Goodbye!"
    exit "${1}"

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Update Welcome Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateWelcomeDialog() {
    sleep 0.3
    echo "${1}" >> "${dialogWelcomeLog}"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for running processes (supplied as Parameter 1)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function procesStatus() {

    processToCheck="${1}"
    logComment "Process: ${processToCheck}"
    processToCheckStatus=$( /usr/bin/pgrep -x "${processToCheck}" )
    if [[ -n ${processToCheckStatus} ]]; then
        processCheckResult+="'${processToCheck}' running; "
    else
        processCheckResult+="'${processToCheck}' NOT running; "
    fi

}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for assigned flexibilty
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function flexibilityCheck() {

    case "${loggedInUserGroupMembership}" in

        *"high"*    )   assignedFlexibility="High"      ;;
        *"medium"*  )   assignedFlexibility="Medium"    ;;
        *"low"*     )   assignedFlexibility="Low"       ;;
        *           )
            workstyle=$( grep '"Workstyle":' /var/log/defendpoint/audit.log | tail -n 1 | awk -F'": "' '{print $3,$NF}' | sed 's/",//g; s/^ *//g' )
            assignedFlexibility="${workstyle}"
            ;;

    esac

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

preFlight "\n\n###\n# $humanReadableScriptName (${scriptVersion})\n# Operation Mode: ${operationMode}\n###\n"
preFlight "Initiating …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
    fatal "This script must be run as root; exiting."
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate swiftDialog is installed
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

preFlight "Validate swiftDialog is installed"
dialogCheck



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Validate BeyondTrust EPM installation (or exit with error)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -e "/Applications/PrivilegeManagement.app" ]]; then
    preFlight "BeyondTrust EPM Client installed; proceeding …"
else
    fatal "BeyondTrust EPM Client NOT installed; exiting"
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
# Create Welcome Dialog
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

notice "Create Welcome Dialog …"

eval "$dialogWelcome" & sleep 0.3

if [[ ${operationMode} == "debug" ]]; then

    updateWelcomeDialog "title: DEBUG MODE | $title"
    sleep "${anticipationDuration}"
    updateWelcomeDialog "message: DEBUG MODE. Please wait for ${anticipationDuration} seconds …"
    updateWelcomeDialog "progresstext: DEBUG MODE. Pausing for ${anticipationDuration} seconds"
    sleep "${anticipationDuration}"
    computerName="DEBUG"
    btEpmClient="DEBUG"
    btEpmAdapter="DEBUG"
    btEpmPackageManager="DEBUG"
    systemExtensionStatus="DEBUG"
    policyName="DEBUG"
    policyRevision="DEBUG"
    updateWelcomeDialog "message: **Results for ${loggedInUser}**<br><br><br>- **macOS Version:** ${osVersion} (${osBuild})<br>- **Policy Name and Revision:** ${policyName} (r${policyRevision})<br>- **Computer Name:** ${computerName}<br>- **Installation Status:** DEBUG<br>- **Client Version:** ${btEpmClient} <br>- **Adapter Version:** ${btEpmAdapter}<br>- **Package Manager Version:** ${btEpmPackageManager}<br>- **System Extension:** ${systemExtensionStatus}"

else

    updateWelcomeDialog "progress: increment"
    updateWelcomeDialog "progresstext: Inspecting …"
    sleep "${anticipationDuration}"

    SECONDS="0"

    # BeyondTrust EPM Inspection: Computer Name
    info "Computer Name"
    computerName=$( scutil --get LocalHostName )
    updateWelcomeDialog "progress: increment"
    updateWelcomeDialog "progresstext: Computer Name …"

    # BeyondTrust EPM Inspection: Installation
    info "Installation"
    updateWelcomeDialog "progress: increment"
    updateWelcomeDialog "progresstext: Installation …"

    # BeyondTrust EPM Inspection: Client Version
    info "Client Version"
    btEpmClient=$( defaults read /Applications/PrivilegeManagement.app/Contents/Info.plist CFBundleVersion )
    updateWelcomeDialog "progress: increment"
    updateWelcomeDialog "progresstext: Client Version …"

    # BeyondTrust EPM Inspection: Adapter Version
    info "Adapter Version"
    btEpmAdapter=$( defaults read /usr/local/libexec/Avecto/iC3Adapter/1.0/PMCAdapter.app/Contents/Info.plist CFBundleVersion )
    updateWelcomeDialog "progress: increment"
    updateWelcomeDialog "progresstext: Adapter Version …"

    # BeyondTrust EPM Inspection: Package Manager Version
    info "Package Manager Version"
    btEpmPackageManager=$( defaults read /Applications/BeyondTrust/PMCPackageManager.app/Contents/Info.plist CFBundleVersion )
    updateWelcomeDialog "progress: increment"
    updateWelcomeDialog "progresstext: Package Manager Version …"

    # BeyondTrust EPM Inspection: System Extension
    info "System Extension"
    systemExtensionStatus=$( systemextensionsctl list | awk -F"[][]" '/com.beyondtrust.endpointsecurity/ {print $2}' )
    updateWelcomeDialog "progress: increment"
    updateWelcomeDialog "progresstext: System Extension …"

    # BeyondTrust EPM Inspection: Policy Name and Revision
    info "Policy Name and Revision"
    policyName=$( xmllint --xpath "string(//@PolicyName)" "${targetPolicy}" )
    policyRevision=$( xmllint --xpath "string(//@RevisionNumber)" "${targetPolicy}" )
    updateWelcomeDialog "progress: increment"
    updateWelcomeDialog "progresstext: Policy Name and Revision …"

    # BeyondTrust EPM Inspection: Policy Checksum Validation
    info "Policy Checksum Validation"
    if [[ "${clientPolicyChecksum}" == "${expectedPolicyChecksum}" ]]; then
        checksumValidation="Checksum Passed"
        logComment "${checksumValidation}"
    else
        checksumValidation="Checksum Failed"
        warning "${checksumValidation}"
    fi
    updateWelcomeDialog "progress: increment"
    updateWelcomeDialog "progresstext: Policy Checksum Validation …"

    # BeyondTrust EPM Inspection: Assigned Flexibility
    info "Assigned Flexibility"
    flexibilityCheck
    updateWelcomeDialog "progress: increment"
    updateWelcomeDialog "progresstext: Assigned Flexibility …"

    # BeyondTrust EPM Inspection: Processes
    info "Processes"
    updateWelcomeDialog "progress: increment"
    updateWelcomeDialog "progresstext: BeyondTrust EPM Process 1 of 6 …"
    procesStatus "defendpointd"

    updateWelcomeDialog "progress: increment"
    updateWelcomeDialog "progresstext: BeyondTrust EPM Process 2 of 6 …"
    procesStatus "Custodian"

    updateWelcomeDialog "progress: increment"
    updateWelcomeDialog "progresstext: BeyondTrust EPM Process 3 of 6 …"
    procesStatus "PMCAdapter"

    updateWelcomeDialog "progress: increment"
    updateWelcomeDialog "progresstext: BeyondTrust EPM Process 4 of 6 …"
    procesStatus "PMCPackageManager"

    updateWelcomeDialog "progress: increment"
    updateWelcomeDialog "progresstext: BeyondTrust EPM Process 5 of 6 …"
	procesStatus "PrivilegeManagement"

    updateWelcomeDialog "progress: increment"
    updateWelcomeDialog "progresstext: BeyondTrust EPM Process 6 of 6 …"
	procesStatus "NewPrivilegeManagement"

    processCheckResult=${processCheckResult/%; }

    ###
    # BeyondTrust EPM Inspection: Output results to log
    ###

    notice "Output results to log"
    updateWelcomeDialog "progress: increment"
    updateWelcomeDialog "progresstext: Analyzing …"
    logComment "Results for ${loggedInUser}:"
    info "$( id "${loggedInUser}" )"
    logComment "Computer Name: ${computerName}"
    logComment "macOS Version: ${osVersion} (${osBuild})"
    logComment "EPM Accounts: $( dscl . list /Users | grep -E "(_avectodaemon|_defendpoint)" | tr '\n' ' ')"
    logComment "Installation Status: Installed"
    logComment "UseSheets Status: ${useSheetStatusHumanReadable}"
    logComment "Server: $( defaults read /Library/Application\ Support/Avecto/iC3Adapter/config.plist Server )"
    logComment "Client Version: ${btEpmClient}"
    logComment "Adapter Version: ${btEpmAdapter}"
    logComment "Package Manager Version: ${btEpmPackageManager}"
    logComment "System Extension: ${systemExtensionStatus}"
    logComment "Policy Name and Revision: ${policyName} (r${policyRevision})"
    logComment "Assigned Flexibility: ${assignedFlexibility}"
    if [[ "${checksumValidation}" == *"Failed" ]]; then
        warning "Policy Checksum Validation: ${checksumValidation}"
    else
        logComment "Policy Checksum Validation: ${checksumValidation}"
    fi
    info "Processes: ${processCheckResult}"
    info "PMfM Status: $( pmfm status )"
    info "pmfmdiag: $( pmfmdiag all )"
    info "sudo.conf Check: $( ls -lah /etc/sudo.conf )"
    info "sudo.conf Contents: $( cat /etc/sudo.conf )"
    info "sudoserver Check: $(  ls -lah /var/run/defendpoint_sudoserver )"

    if [[ "${operationMode}" == "verbose" ]]; then

        info "Output 'defendpoint.plist' to ${scriptLog} …"
        plutil -p /Library/Application\ Support/Avecto/Defendpoint/defendpoint.plist  >> "${scriptLog}"

        info "Output MDM Overrides to ${scriptLog} …"
        plutil -p /Library/Application\ Support/com.apple.TCC/MDMOverrides.plist >> "${scriptLog}"

    fi

    # BeyondTrust EPM Inspection: Display results to user
    notice "Display results to user"
    timestamp="$( date '+%Y-%m-%d-%H%M%S' )"
    updateWelcomeDialog "message: \
**Results for ${loggedInUser} on ${timestamp}**<br><br><br> \
- **macOS Version:** ${osVersion} (${osBuild})<br> \
- **Policy Name and Revision:** ${policyName} (r${policyRevision})<br> \
- **Assigned Flexibility:** ${assignedFlexibility}<br> \
- **Computer Name:** ${computerName}<br> \
- **Installation Status:** Installed<br> \
- **Client Version:** ${btEpmClient} <br> \
- **Adapter Version:** ${btEpmAdapter}<br> \
- **Package Manager Version:** ${btEpmPackageManager}<br> \
- **System Extension:** ${systemExtensionStatus}
"
    updateWelcomeDialog "progress: complete"
    updateWelcomeDialog "progresstext: Complete!"
    sleep "${anticipationDuration}"

fi

updateWelcomeDialog "button1text: Done"
updateWelcomeDialog "button1: enable"
updateWelcomeDialog "progress: 100"
updateWelcomeDialog "progresstext: Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Exit
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

wait

info "Elapsed Time: $(printf '%dh:%dm:%ds\n' $((SECONDS/3600)) $((SECONDS%3600/60)) $((SECONDS%60)))"

quitOut "End-of-line."

quitScript "0"