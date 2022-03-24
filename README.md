# About
This repository consists of an interactive script to easily install basic software modules and configure a freshly installed Linux. So far it only supports Ubuntu Linux.

# Instructions
Download the script:
```shell
wget https://raw.githubusercontent.com/Lenz-K/setup-script/main/setup-script.sh
```
Make it executable:
```shell
chmod a+x setup-script.sh
```
Execute it:
```shell
sudo ./setup-script.sh
```

# Features
The interactive script will update the system and will then ask to install and set up the following software modules and features:

- automatic updates   
_Note: ExpressVPN is not automatically updated so far. Find information about updating it in the section [Updating ExpressVPN](https://github.com/Lenz-K/setup-script#updating-expressvpn")._
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
