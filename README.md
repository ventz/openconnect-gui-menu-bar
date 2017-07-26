### OpenConnect - OS X GUI Menu Bar for connecting/disconnecting

# What is this?

An easy way to get OpenConnect VPN to have an OS X Menu Bar GUI for:
* quick connecting
* quick disconnect
* status changes (icon)

Full support for multi-factor authentication (especially Duo)!

![OpenConnect Connected](https://github.com/ventz/openconnect-gui-menu-bar/blob/master/images/vpn-connected.png)

![OpenConnect Disconnected](https://github.com/ventz/openconnect-gui-menu-bar/blob/master/images/vpn-disconnected.png)

# How to run it:

## 1. Get the latest BitBar release:
https://github.com/matryer/bitbar/releases

BitBar provides an easy way to put "things" (for output and input) in your OS X Menu Bar.

Just unzip the release in your /Application folder and launch BitBar.
It will ask you to create (or select) a folder to use for your scripts.

## 2. Edit the "openconnect.sh" and follow the steps inside to customize:

This file is the "script" that interacts with BitBar. Place
it in your bitbar scripts folder, and edit it/follow these steps:

### First - Update your sudoers file with:
```
osx-username ALL=(ALL) NOPASSWD: /usr/local/bin/openconnect
osx-username ALL=(ALL) NOPASSWD: /usr/bin/killall -2 openconnect
```

### Second - Make sure your openconnect binary is here:
```
VPN_EXECUTABLE=/usr/local/bin/openconnect
```

### Third - add your VPN domain and VPN username:
```
VPN_HOST="vpn.domain.tld"
VPN_USERNAME="vpn_username@domain.tld#VPN_TUNNEL_OPTIONALLY"
```

### Finally, create your KeyChain password (to store your VPN password securely):
```
a.) Open "Keychain Access" and
b.) Click on "login" keychain (top left corner)
c.) Click on "Passwords" category (bottom left corner)
d.) From the "File" menu, select -> "New Password Item..."
e.) For "Keychain Item Name" and "Account Name" use the value for "VPN_HOST"
f.) For "Password" enter your VPN AnyConnect password.
```

That's it! Now you can use the GUI to connect and disconnect!
(and if you are using Duo - get the 2nd factor push to your phone)

# Help/Questions/Comments:
For help or more info, feel free to contact me or open an issue here!
