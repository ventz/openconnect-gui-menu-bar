#!/bin/bash
# Credit for original concept and initial work to: Jesse Jarzynka
#
# Updated by: Ventz Petkov (8-11-26)
#   * MIGRATED TO SwiftBar (https://github.com/swiftbar/SwiftBar) -- a drop-in
#     replacement for BitBar/xbar with more features, better support, and far
#     better optimization/resource usage. Existing plugins run unchanged.
#   * $0 is not dependable once SwiftBar wraps the plugin in bash, so the menu
#     items now re-invoke $SWIFTBAR_PLUGIN_PATH (falling back to $0 on xbar)
#   * connect/disconnect items are colored with SwiftBar "light,dark" color
#     pairs -- a bare "green"/"red" washes out on the light translucent menu
#   * <swiftbar.refreshOnOpen> re-checks the tunnel every time you open the
#     menu; this plugin has no refresh interval in its filename, so previously
#     the status only updated when you clicked something
#   * LOG_FILE renamed to /tmp/openconnect-menubar.log (was -xbar.log)
#   * metadata switched from <bitbar.*> to the <xbar.*> tags SwiftBar reads
#
# Updated by: Ventz Petkov (8-7-26)
#   * added "sso" auth mode for browser-based SAML/Okta/Azure AD deployments
#     (see VPN_AUTH) -- auth happens entirely in the browser via --external-browser,
#     with NO password or 2FA fed to openconnect
#   * added clear_stale_route() -- openconnect pins the VPN gateway with a /32
#     host route OUTSIDE the tunnel; if a session dies without a clean teardown
#     that route is left behind bound to a stale source address, and every later
#     connect fails instantly with "Can't assign requested address" before it
#     ever reaches auth. Now cleared on both connect and disconnect.
#   * replaced the unbounded "until connected" spin with a bounded wait
#     (see CONNECT_TIMEOUT), so a stuck connect no longer hangs the plugin forever
#   * openconnect output now goes to $LOG_FILE instead of /dev/null, plus a
#     "View log" menu item -- a failed connect is now diagnosable
#   * keychain lookup scoped by BOTH service and account, so a second item with
#     the same label cannot shadow it; empty result now fails loudly
#
# Updated by: Ventz Petkov (11-08-23)
#   * Modified VPN_EXECUTABLE default path due to dir change within `brew` on M-series Macs (m1, m2, m3) to /opt/homebrew/
#   * Modified sudoers to reflect new openconnect VPN_EXECUTABLE path
#   * Cleaned up KeyChain instructions around KeyChain Item name vs Account Name
#
# Updated by: Ventz Petkov (7-25-23)
#   * added useragent for AnyConnect (needed for recent deployments)
#   * added "VPN_GROUP" option, which is replacing the phased out "#VPN_TUNNEL_OPTIONALLY" within the "VPN_USERNAME"

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

# <xbar.title>VPN Status</xbar.title>
# <xbar.version>v2.0</xbar.version>
# <xbar.author>Ventz Petkov</xbar.author>
# <xbar.author.github>ventz</xbar.author.github>
# <xbar.desc>Connect/Disconnect OpenConnect + show status</xbar.desc>
# <xbar.image></xbar.image>
#
# SwiftBar-only: re-check the tunnel state each time the menu is opened. This
# plugin has no refresh interval in its filename, so without it the status is
# only as fresh as your last click. (Ignored by xbar/BitBar.)
# <swiftbar.refreshOnOpen>true</swiftbar.refreshOnOpen>

#########################################################
# USER CHANGES #
#########################################################

# 1.) Updated your sudo config with (edit "mac-username" with your username):
# (NOTE: You can obtain the "mac-username" with "whoami" in a terminal)
#mac-username ALL=(ALL) NOPASSWD: /opt/homebrew/bin/openconnect
#mac-username ALL=(ALL) NOPASSWD: /usr/bin/killall -2 openconnect
#mac-username ALL=(ALL) NOPASSWD: /sbin/route -n delete -host *
#
# NOTE: the third line is what lets the plugin clean up the stale VPN gateway
# route (see clear_stale_route below). Without it, that cleanup is skipped and
# logged -- it will NOT hang waiting for a password, but you will eventually hit
# "Can't assign requested address" and have to clear the route by hand:
#   sudo route -n delete -host <vpn-server-ip>
# ALWAYS validate after editing sudoers:  sudo visudo -c


# 2.) Make sure openconnect binary is located here:
#     (If you don't have it installed: "brew install openconnect")
VPN_EXECUTABLE=/opt/homebrew/bin/openconnect


# 3.) Update your AnyConnect VPN host
VPN_HOST="vpn.domain.tld"
# NOTE: If you are using a VPN_GROUP (ex: domain.tld/group) -- use this, instead of "#VPN_TUNNEL" within VPN_USERNAME
VPN_GROUP="VPN_GROUP_TUNNEL_OPTIONALLY"

# 4.) Update your AnyConnect username + tunnel
# NOTE: If you are NOT using the VPN_GROUP, set it to empty, and use "#VPN_TUNNEL" within the VPN_USERNAME
VPN_USERNAME="vpn_username@domain.tld#VPN_TUNNEL_OPTIONALLY"

# 5.) Authentication method for your VPN:
#   "password" -> classic AnyConnect: keychain password + 2FA (see PUSH_OR_PIN below)
#   "sso"      -> browser-based SSO (SAML / Okta / Azure AD / Ping / etc.)
#
# With "sso" there is NO password and NO 2FA prompt here -- openconnect hands the
# whole exchange to your browser, and any MFA happens there. If your org has
# migrated to SSO, the keychain entry and PUSH_OR_PIN below become unused.
VPN_AUTH="password"

# Only used when VPN_AUTH="sso" -- helper that opens the SSO URL in your browser.
# Shipped alongside this script; see sso_browser.sh for why a helper is needed
# (openconnect runs as root under sudo, and root must NOT launch your browser).
EXTERNAL_BROWSER="$(dirname "$0")/sso_browser.sh"

# 5b.) Push 2FA (ex: Duo), or Pin/Token (ex: Yubikey, Google Authenticator, TOTP)
#      (VPN_AUTH="password" only -- ignored when VPN_AUTH="sso")
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
#     (VPN_AUTH="password" only -- skip this entirely when VPN_AUTH="sso")
#      a.) Open "Keychain Access" and 
#      b.) Click on "login" keychain (top left corner)
#      c.) Click on "Passwords" category (bottom left corner)
#      d.) From the "File" menu, select -> "New Password Item..."
#      e.) For "Keychain Item Name" "VPN_HOST" (ex: vpn.domain.tld)
#      f.) For "Account Name" use the value for "VPN_USERNAME" (ex: email@domain.tld)
#      g.) For "Password" enter your VPN AnyConnect password.

# This will retrieve that password securely at run time when you connect, and feed it to openconnect
# No storing passwords unenin plain text files! :)
# Scoped by BOTH service (-s) and account (-a) so a second keychain item sharing
# the same label cannot silently shadow the right one.
GET_VPN_PASSWORD="security find-generic-password -s $VPN_HOST -a $VPN_USERNAME -w"

# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
# END-OF-USER-SETTINGS #
#########################################################

VPN_INTERFACE="utun99"

# Give up rather than spin forever if the tunnel never comes up.
CONNECT_TIMEOUT=60
# openconnect's own output lands here instead of /dev/null, so a failed connect
# is diagnosable after the fact ("View log" in the menu).
LOG_FILE="/tmp/openconnect-menubar.log"

# SwiftBar exports the running plugin's own path. $0 is not dependable, because
# SwiftBar runs plugins through bash by default (<swiftbar.runInBash>), and the
# menu items below re-invoke THIS file with an argument -- so the path has to be
# absolute. Falls back to $0 under xbar/BitBar.
SELF="${SWIFTBAR_PLUGIN_PATH:-$0}"

# Menu item colors. SwiftBar accepts a "light_color,dark_color" pair and picks
# the right one for the current system appearance. A bare "green"/"red" is the
# dark-mode tuned value and washes out on the light translucent menu.
# (xbar/BitBar don't understand the pair -- drop the second half if you use one.)
CONNECT_COLOR="#0b7a2f,#30d158"
DISCONNECT_COLOR="#a6252a,#ff453a"

# Command to determine if VPN is connected or disconnected
VPN_CONNECTED="/sbin/ifconfig | grep -A3 $VPN_INTERFACE | grep inet"
# Command to run to disconnect VPN
VPN_DISCONNECT_CMD="sudo killall -2 openconnect"

# openconnect pins the VPN gateway with a /32 host route that stays OUTSIDE the
# tunnel (otherwise the tunnel's own default route would swallow the connection
# to the gateway). When a session dies without a clean teardown -- killall -2,
# laptop sleep, an address change on your LAN interface -- that route is left
# behind bound to a stale source address. Every later connect then dies with
#   Failed to connect to <ip>:443: Can't assign requested address
# BEFORE it ever reaches authentication, so no password/SSO prompt ever appears
# and the failure looks like a hang. Clear it first.
function clear_stale_route() {
	local host="$1" ip
	for ip in $(dig +short "$host" | grep -E '^[0-9]+(\.[0-9]+){3}$'); do
		if netstat -rn -f inet | grep -q "^${ip}[[:space:]]"; then
			echo "clearing stale host route for $ip" >> "$LOG_FILE"
			# -n (non-interactive): SwiftBar runs this with terminal=false, so an
			# unexpected sudo password prompt would hang the plugin invisibly.
			# Fail loudly into the log instead. Needs the /sbin/route sudoers line.
			if ! sudo -n /sbin/route -n delete -host "$ip" >> "$LOG_FILE" 2>&1; then
				echo "ERROR: could not delete route for $ip -- add the /sbin/route NOPASSWD sudoers line" >> "$LOG_FILE"
			fi
		fi
	done
}

# Wait for the tunnel so the menu item refreshes instantly -- but bounded, so a
# stuck connect leaves the menu usable instead of hanging the plugin forever.
function wait_for_connect() {
	local waited=0
	until eval "$VPN_CONNECTED" &> /dev/null; do
		sleep 1
		waited=$((waited + 1))
		if [ "$waited" -ge "$CONNECT_TIMEOUT" ]; then
			echo "timed out after ${CONNECT_TIMEOUT}s waiting for $VPN_INTERFACE" >> "$LOG_FILE"
			return 1
		fi
	done
	return 0
}

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
			text returned of (display dialog "Enter $1 token:" with hidden answer default answer "" buttons {"OK"} default button 1 with title "$(basename $0)")
		end tell
EOF
	fi
}


case "$1" in
    connect)
        : > "$LOG_FILE"
        clear_stale_route "$VPN_HOST"
        # VPN connection command, should eventually result in $VPN_CONNECTED,
        # may need to be modified for VPN clients other than openconnect

        if [ "$VPN_AUTH" == "sso" ]; then
            # Browser-based SSO: openconnect hands the whole exchange to
            # $EXTERNAL_BROWSER and any MFA happens there. stdin is closed
            # deliberately -- leaving a pipe on stdin (the password form below)
            # silently swallows openconnect's own prompts and makes a failed SSO
            # look identical to a hang.
            sudo "$VPN_EXECUTABLE" --useragent=AnyConnect --external-browser="$EXTERNAL_BROWSER" -u "$VPN_USERNAME" -i "$VPN_INTERFACE" "$VPN_HOST/$VPN_GROUP" < /dev/null >> "$LOG_FILE" 2>&1 &

            wait_for_connect
        else
            VPN_PASSWORD=$(eval "$GET_VPN_PASSWORD")
            if [ -z "$VPN_PASSWORD" ]; then
                # Fall through to the menu rather than exiting silently -- an
                # empty password used to get piped straight into openconnect,
                # which then failed for a reason that looked nothing like
                # "missing keychain entry".
                echo "ERROR: no keychain password for $VPN_HOST (account $VPN_USERNAME)" >> "$LOG_FILE"
            else
                # Connect based on your 2FA selection (see: $PUSH_OR_PIN for options)
                # For anything else (non-duo) - you would provide your token (see: stoken)
                echo -e "${VPN_PASSWORD}\n$(prompt_2fa_method ${PUSH_OR_PIN})\n" | sudo "$VPN_EXECUTABLE" --useragent=AnyConnect -u "$VPN_USERNAME" -i "$VPN_INTERFACE" "$VPN_HOST/$VPN_GROUP" >> "$LOG_FILE" 2>&1 &

                wait_for_connect
            fi
        fi
        ;;
    disconnect)
        eval "$VPN_DISCONNECT_CMD"
        # Wait for disconnection so menu item refreshes instantly
        until [ -z "$(eval "$VPN_CONNECTED")" ]; do sleep 1; done
        # Tear down the gateway host route openconnect left behind, so the NEXT
        # connect isn't poisoned by it.
        clear_stale_route "$VPN_HOST"
        ;;
esac


if [ -n "$(eval "$VPN_CONNECTED")" ]; then
    echo "VPN 🔒"
    echo '---'
    echo "Disconnect VPN | color=$DISCONNECT_COLOR bash='$SELF' param1=disconnect terminal=false refresh=true"
    echo '---'
    echo "View log | href=file://$LOG_FILE"
    exit
else
    echo "VPN ❌"
    # Alternative icon -> but too similar to "connected"
    #echo "VPN 🔓"
    echo '---'
    echo "Connect VPN | color=$CONNECT_COLOR bash='$SELF' param1=connect terminal=false refresh=true"
    echo '---'
    echo "View log | href=file://$LOG_FILE"
    # For debugging!
    #echo "Connect VPN | bash='$SELF' param1=connect terminal=true refresh=true"
    exit
fi
