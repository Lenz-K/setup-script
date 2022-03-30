# About
This repository consists of an interactive script to easily install basic software modules and configure a freshly installed Linux. So far it supports Ubuntu and Manjaro Linux. ExpressVPN only works on a x86 system.

# Instructions
Download the script with wget or copy the [content](https://github.com/Lenz-K/setup-script/blob/main/setup-script.sh) into a file called `setup-script.sh`:
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
