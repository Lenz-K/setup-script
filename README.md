# About
This repository consists of an interactive script to set up a fresh install of Linux. So far it only supports Ubuntu Linux. Copy the script to your machine and run it:

```shell
sudo ./setup-script.sh
```

# Features
The interactive script will update the system and will then ask to install and set up the following software modules and features:

- automatic updates   
_Note: ExpressVPN is not automatically updated so far. Find information about updating it in the section Updating ExpressVPN._
- git
- python and pip
- cryptsetup
- ExpressVPN
- ufw (Uncomplicated Firewall)

## Updating ExpressVPN
To retrieve the currently installed version run:
```commandline
expressvpn --version
```
The instructions for updating can be found on the following web pages:

- [Latest Version Download Page](https://www.expressvpn.com/latest)
- [Installation Instructions](https://www.expressvpn.com/support/vpn-setup/app-for-linux/#install)
- [Verification Instructions](https://www.expressvpn.com/support/vpn-setup/pgp-for-linux/)
