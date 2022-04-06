# About
This repository consists of an interactive script to easily install basic software modules and configure a freshly installed Linux. So far it supports Ubuntu and Manjaro Linux. It is tested on x86 and arm64.

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
The interactive script will update the system and will then ask to install and configure the following software modules and features:

- automatic updates
- git
- python and pip
- cryptsetup  
_Note: Needed to mount or create encrypted devices._
- cifs-utils  
_Note: Needed to mount SMB network shared directories._
- ExpressVPN  
_Note: ExpressVPN is only supported on x86 systems._
- ufw (Uncomplicated Firewall)
- OpenSSH
