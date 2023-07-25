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
mac-username ALL=(ALL) NOPASSWD: /usr/local/bin/openconnect
mac-username ALL=(ALL) NOPASSWD: /usr/bin/killall -2 openconnect
```

Please note that `mac-username` is not a literal, but the actually the 'whoami' username for OS X/Mac OS.

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

### Finally, create your KeyChain password (to store your VPN password securely):
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
