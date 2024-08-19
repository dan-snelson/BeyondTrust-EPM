#!/bin/zsh --no-rcs 
# shellcheck shell=bash

####################################################################################################
#
# ABOUT
#
#   BeyondTrust PMfM Workstyle
#
#   Determines the last logged-in user's assigned BeyondTrust Workstyle.
#   See: [BeyondTrust EPM: Flexibilities](https://snelson.us/2024/08/beyondtrust-epm-flexibilities/)
#
####################################################################################################
#
# HISTORY
#
# Version 0.0.1, 17-Aug-2024, Dan K. Snelson (@dan-snelson)
#   - Original Version (inspired by @Mike Wolf)
#
# Version 0.0.2, 19-Aug-2024, Dan K. Snelson (@dan-snelson)
#   - Parse audit.log for more recently reported Workstyle (inspired by @tziegmann)
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

scriptVersion="0.0.2"
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin/

# Last Logged-in User
lastUser=$( defaults read /Library/Preferences/com.apple.loginwindow.plist lastUserName )

# Last Logged-in User's Group Membership
lastUserGroupMembership=$( id -Gn "${lastUser}" )



####################################################################################################
#
# Program
#
####################################################################################################

case "${lastUserGroupMembership}" in

    *"high"*    )
        echo "<result>High</result>"
        ;;

    *"medium"*  )
        echo "<result>Medium</result>"
        ;;

    *"low"*     )
        echo "<result>Low</result>"
        ;;

    *           )
        workstyle=$( grep '"Workstyle":' /var/log/defendpoint/audit.log | tail -n 1 | awk -F'": "' '{print $3,$NF}' | sed 's/",//g; s/^ *//g' )
        echo "<result>${workstyle}</result>"
        ;;

esac


exit 0