### OpenConnect - OS X/Mac OS GUI Menu Bar for connecting/disconnecting

# What is this?

An easy way to get OpenConnect VPN to have an OS X/Mac OS Menu Bar GUI for:
* quick connecting
* quick disconnect
* status changes (icon)

Full support for multi-factor authentication (especially Duo)!

![OpenConnect Connected](https://github.com/ventz/openconnect-gui-menu-bar/blob/master/images/vpn-connected.png)

![OpenConnect Disconnected](https://github.com/ventz/openconnect-gui-menu-bar/blob/master/images/vpn-disconnected.png)

# How to run it:

## 1. Get the latest BitBar release:
https://github.com/matryer/bitbar/releases

BitBar provides an easy way to put "things" (for output and input) in your OS X/Mac OS Menu Bar.

Just unzip the release in your /Application folder and launch BitBar.
It will ask you to create (or select) a folder to use for your scripts.

Obviously make sure you have installed openconnect too :)
`brew install openconnect`

## 2. Edit the "openconnect.sh" and follow the steps inside to customize:

Start by just getting the file itself:
https://raw.githubusercontent.com/ventz/openconnect-gui-menu-bar/master/openconnect.sh

Make sure you make it executable: `chmod 755 openconnect.sh` once you download it.

This file is the "script" that interacts with BitBar. Place
it in your bitbar scripts folder (I have chosen:
~/Documents/bitbar-plugins/), and edit it/follow these steps:

### First - Update your sudoers file with:

You can create a `/etc/sudoers.d/openconnect` file which contains:
```
mac-username ALL=(ALL) NOPASSWD: /opt/homebrew/bin/openconnect
mac-username ALL=(ALL) NOPASSWD: /usr/bin/killall -2 openconnect
mac-username ALL=(ALL) NOPASSWD: /sbin/route -n delete -host *
```

Please note that `mac-username` is not a literal, but the actually the 'whoami' username for OS X/Mac OS.

The third line lets the plugin clean up the stale VPN gateway route automatically
(see "Problems Connecting?" below). Without it that cleanup is skipped and logged
— it will *not* hang waiting for a password, but you will eventually have to
clear the route by hand.

Always validate the file after editing it — a malformed sudoers file can lock you
out of `sudo` entirely:
```
sudo visudo -c
```

### Second - Make sure your openconnect binary is here:
```
VPN_EXECUTABLE=/usr/local/bin/openconnect
```

### Third - add your VPN domain and VPN username and set Auth for "push" or "pin"
```
VPN_HOST="vpn.domain.tld"
# NOTE: If you are using a VPN_GROUP (ex: domain.tld/group) -- use this, instead of "#VPN_TUNNEL" within VPN_USERNAME
VPN_GROUP="VPN_GROUP_TUNNEL"
VPN_USERNAME="vpn_username@domain.tld#VPN_TUNNEL_OPTIONALLY"

# Duo options include "push", "sms", or "phone"
PUSH_OR_PIN="push"
* or * 
# To be prompted for TOTP input, use product name:
PUSH_OR_PIN="Yubikey"
or
PUSH_OR_PIN="Google Authenticator"
or
PUSH_OR_PIN="Duo"

```

### Using SSO (SAML / Okta / Azure AD / Ping) instead of a password?

Many organizations have migrated their AnyConnect/ASA deployments to browser-based
SSO. If yours has, set:
```
VPN_AUTH="sso"
```

With `VPN_AUTH="sso"` there is **no password and no 2FA prompt** in this script —
openconnect hands the entire exchange to your browser, and any MFA (Duo push,
number matching, etc.) happens there. The KeyChain step below and `PUSH_OR_PIN`
both become unused.

This uses `sso_browser.sh`, shipped alongside `openconnect.sh` — download it too
and `chmod 755 sso_browser.sh`. Keep both files in the same folder, or point
`EXTERNAL_BROWSER` at wherever you put it. Edit `SSO_BROWSER` inside it to pick
your browser (defaults to `Google Chrome`; leave it empty for your system default).

The helper exists for a specific reason: openconnect runs under `sudo`, so
anything it spawns runs as **root**. Pointing `--external-browser` straight at a
browser means root writes into *your* browser profile (corrupting it over time),
and a root process isn't reliably attached to your GUI session — so the login
window may never appear and the connect just looks like it hung. The helper drops
back to the console user and uses `open -a`, which also hands the URL to your
**already-running** browser with its default profile — the one holding your live
SSO session cookies.

### Finally, create your KeyChain password (to store your VPN password securely):
(Skip this entirely if you set `VPN_AUTH="sso"` above.)
```
a.) Open "Keychain Access" and
b.) Click on "login" keychain (top left corner)
c.) Click on "Passwords" category (bottom left corner)
d.) From the "File" menu, select -> "New Password Item..."
e.) For "Keychain Item Name" and "Account Name" use the "VPN_HOST" and "VPN_USERNAME" values respectively from the "Third" step above.
f.) For "Password" enter your VPN AnyConnect password.
```

That's it! Now you can use the GUI to connect and disconnect!
(and if you are using Duo - get the 2nd factor push to your phone)


# Problems Connecting?

## "Can't assign requested address" / no prompt ever appears

If the log shows:
```
Failed to connect to <vpn-server-ip>:443: Can't assign requested address
```
then a **stale VPN gateway route** is the culprit. openconnect pins the VPN
server with a `/32` host route that deliberately stays *outside* the tunnel
(otherwise the tunnel's own default route would swallow the connection back to
the gateway). When a session dies without a clean teardown — `killall -2`, laptop
sleep, a DHCP address change on your LAN interface — that route is left behind
bound to a source address that no longer exists.

Every later connect then fails **instantly**, at the TCP layer, *before*
authentication. So no password prompt and no SSO browser window ever appears, and
the whole thing looks like a hang rather than an error. Check for it with:
```
netstat -rn -f inet | grep <vpn-server-ip>
```
and clear it with:
```
sudo route -n delete -host <vpn-server-ip>
```

`openconnect.sh` now does this automatically on both connect and disconnect
(`clear_stale_route`), provided you added the `/sbin/route` sudoers line above.

## Connect seems to hang forever

Older versions spun in an unbounded `until connected` loop with all output sent to
`/dev/null`, so any failure hung the plugin silently. Connects are now bounded by
`CONNECT_TIMEOUT` (default 60s) and openconnect's output goes to
`/tmp/openconnect-xbar.log` — reachable from the **View log** menu item.

## utun interface collisions

If you have another VPN (ex: OpenVPN), you might already have an
'utun0' interface. Please check with '/sbin/ifconfig'. If that's the
case, in step #2 above you need to add:

```
VPN_INTERFACE="utun1"
```

If you already have an utun0 and an utun1, then you need to
change it to the next available, ex: utun2.

In order to make sure this doesn't happen - I've chosen 'utun99'

# Help/Questions/Comments:
For help or more info, feel free to contact me or open an issue here!
