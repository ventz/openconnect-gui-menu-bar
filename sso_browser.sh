#!/bin/bash
# openconnect --external-browser helper (macOS)
#
# Used by openconnect.sh when VPN_AUTH="sso" -- browser-based SAML / Okta /
# Azure AD / Ping authentication. openconnect invokes this with the SSO URL as
# the single argument, and waits for the browser to complete the exchange.
#
# WHY THIS EXISTS (rather than pointing --external-browser straight at a browser):
# openconnect itself runs under sudo, so anything it spawns runs as ROOT. Having
# root launch your browser breaks in two ways:
#   1. Root writes into YOUR browser profile (SingletonLock, crash dumps, cache),
#      which corrupts it over time and can leave root-owned files you then can't
#      delete without sudo.
#   2. A root process is not reliably attached to the logged-in user's Aqua (GUI)
#      session, so the window may never actually appear on screen -- the connect
#      then looks like a silent hang.
# So: drop back to the console user and into their GUI session before opening.
#
# `open -a` (rather than exec'ing the browser binary with an explicit
# --user-data-dir) hands the URL to the ALREADY-RUNNING browser using its default
# profile. That matters: the default profile is the one holding your live SSO
# session cookies, which is usually what lets the login complete without a full
# re-authentication.

URL="$1"

# Which browser to hand the SSO URL to. Must match the application name as macOS
# knows it, e.g. "Google Chrome", "Safari", "Firefox", "Microsoft Edge".
# Leave empty to use whatever your system default browser is.
SSO_BROWSER="Google Chrome"

# The user whose GUI session (and browser profile) should receive the URL.
# Defaults to the current console user, so this normally needs no editing.
# NOTE: /usr/bin/stat is spelled out on purpose -- if you have GNU coreutils on
# your PATH, its `stat` takes -f as "file system" and this silently breaks.
SSO_USER="$(/usr/bin/stat -f '%Su' /dev/console)"

if [ -z "$URL" ]; then
	echo "usage: $(basename "$0") <url>" >&2
	exit 1
fi

if [ -n "$SSO_BROWSER" ]; then
	OPEN_ARGS=(-a "$SSO_BROWSER" "$URL")
else
	OPEN_ARGS=("$URL")
fi

# When invoked as root (the normal case, since openconnect runs under sudo),
# re-enter the console user's GUI session before opening.
if [ "$(id -u)" -eq 0 ]; then
	exec launchctl asuser "$(id -u "$SSO_USER")" sudo -u "$SSO_USER" \
		/usr/bin/open "${OPEN_ARGS[@]}"
fi

exec /usr/bin/open "${OPEN_ARGS[@]}"
