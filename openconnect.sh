#!/bin/bash
# Credit for original concept and initial work to: Jesse Jarzynka

# Updated by: Ventz Petkov (8-31-18)
#   * merged feature for token/pin input (ex: Duo/Yubikey/Google Authenticator) contributed by Harry Hoffman <hhoffman@ip-solutions.net>
#   * added option to pick "push/sms/phone" (ex: Duo) vs token/pin (Yubikey/Google Authenticator/Duo)

# Updated by: Ventz Petkov (11-15-17)
#   * cleared up documentation
#   * incremented 'VPN_INTERFACE' to 'utun99' to avoid collisions with other VPNs

# Updated by: Ventz Petkov (9-28-17)
#   * fixed for Mac OS X High Sierra (10.13)

# Updated by: Ventz Petkov (7-24-17)
#   * fixed openconnect (did not work with new 2nd password prompt)
#   * added ability to work with "Duo" 2-factor auth
#   * changed icons

# <bitbar.title>VPN Status</bitbar.title>
# <bitbar.version>v1.1</bitbar.version>
# <bitbar.author>Ventz Petkov</bitbar.author>
# <bitbar.author.github>ventz</bitbar.author.github>
# <bitbar.desc>Connect/Disconnect OpenConnect + show status</bitbar.desc>
# <bitbar.image></bitbar.image>

#########################################################
# USER CHANGES #
#########################################################

# 1.) Updated your sudo config with (edit "osx-username" with your username):
#osx-username ALL=(ALL) NOPASSWD: /usr/local/bin/openconnect
#osx-username ALL=(ALL) NOPASSWD: /usr/bin/killall -2 openconnect


# 2.) Make sure openconnect binary is located here:
#     (If you don't have it installed: "brew install openconnect")
VPN_EXECUTABLE=/usr/local/bin/openconnect


# 3.) Update your AnyConnect VPN host
VPN_HOST="vpn.domain.tld"

# 4.) Update your AnyConnect username + tunnel
VPN_USERNAME="vpn_username@domain.tld#VPN_TUNNEL_OPTIONALLY"

# 5.) Push 2FA (ex: Duo), or Pin/Token (ex: Yubikey, Google Authenticator, TOTP)
PUSH_OR_PIN="push"
#PUSH_OR_PIN="Yubikey"
# ---
# * For Push (and other Duo specifics), options include:
# "push", "sms", or "phone"
# ---
# * For Yubikey/Google Authenticator/other TOTP, specify any name for prompt:
# "any-name-of-product-to-be-prompted-about"
# PUSH_OR_PIN="Yubikey" | PUSH_OR_PIN="Google Authenticator" | PUSH_OR_PIN="Duo"
# (essentially, anything _other_ than the "push", "sms", or "phone" options)
# ---

# 6.) Create an encrypted password entry in your OS X Keychain:
#      a.) Open "Keychain Access" and 
#      b.) Click on "login" keychain (top left corner)
#      c.) Click on "Passwords" category (bottom left corner)
#      d.) From the "File" menu, select -> "New Password Item..."
#      e.) For "Keychain Item Name" and "Account Name" use the value for "VPN_HOST" and "VPN_USERNAME" respectively
#      f.) For "Password" enter your VPN AnyConnect password.

# This will retrieve that password securely at run time when you connect, and feed it to openconnect
# No storing passwords unenin plain text files! :)
GET_VPN_PASSWORD="security find-generic-password -wl $VPN_HOST"

# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
# END-OF-USER-SETTINGS #
#########################################################

VPN_INTERFACE="utun99"

# Command to determine if VPN is connected or disconnected
VPN_CONNECTED="/sbin/ifconfig | grep -A3 $VPN_INTERFACE | grep inet"
# Command to run to disconnect VPN
VPN_DISCONNECT_CMD="sudo killall -2 openconnect"

# GUI Prompt for your token/key (ex: Duo/Yubikey/Google Authenticator)
function prompt_2fa_method() {		
	if [ "$1" == "push" ]; then
		echo "push"
	elif [ "$1" == "sms" ]; then
		echo "sms"
	elif [ "$1" == "phone" ]; then
		echo "phone"
	else
		osascript <<EOF
		tell app "System Events"
			text returned of (display dialog "Enter $1 token:" default answer "" buttons {"OK"} default button 1 with title "$(basename $0)")
		end tell
EOF
	fi
}


case "$1" in
    connect)
        VPN_PASSWORD=$(eval "$GET_VPN_PASSWORD")
        # VPN connection command, should eventually result in $VPN_CONNECTED,
        # may need to be modified for VPN clients other than openconnect

        # Connect based on your 2FA selection (see: $PUSH_OR_PIN for options)
        # For anything else (non-duo) - you would provide your token (see: stoken)
        echo -e "${VPN_PASSWORD}\n$(prompt_2fa_method ${PUSH_OR_PIN})\n" | sudo "$VPN_EXECUTABLE" -u "$VPN_USERNAME" -i "$VPN_INTERFACE" "$VPN_HOST" &> /dev/null &

        # Wait for connection so menu item refreshes instantly
        until eval "$VPN_CONNECTED"; do sleep 1; done
        ;;
    disconnect)
        eval "$VPN_DISCONNECT_CMD"
        # Wait for disconnection so menu item refreshes instantly
        until [ -z "$(eval "$VPN_CONNECTED")" ]; do sleep 1; done
        ;;
esac


if [ -n "$(eval "$VPN_CONNECTED")" ]; then
    echo "VPN 🔒"
    echo '---'
    echo "Disconnect VPN | bash='$0' param1=disconnect terminal=false refresh=true"
    exit
else
    echo "VPN ❌"
    # Alternative icon -> but too similar to "connected"
    #echo "VPN 🔓"
    echo '---'
    echo "Connect VPN | bash='$0' param1=connect terminal=false refresh=true"
    # For debugging!
    #echo "Connect VPN | bash='$0' param1=connect terminal=true refresh=true"
    exit
fi
