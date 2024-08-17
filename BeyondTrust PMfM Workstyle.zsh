#!/bin/zsh --no-rcs 
# shellcheck shell=bash

####################################################################################################
#
# ABOUT
#
#   BeyondTrust PMfM Workstyle
#
#   Determines the last logged-in user's assigned BeyondTrust Workstyle, presuming the use of
#   [BeyondTrust EPM: Flexibilities](https://snelson.us/2024/08/beyondtrust-epm-flexibilities/)
#
####################################################################################################
#
# HISTORY
#
# Version 0.0.1, 17-Aug-2024, Dan K. Snelson (@dan-snelson)
#   - Original Version (inspired by @Mike Wolf)
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

scriptVersion="0.0.1"
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
        echo "<result>Unknown</result>"
        ;;

esac


exit 0