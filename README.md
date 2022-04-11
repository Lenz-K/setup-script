# About
This repository consists of an interactive script to easily install basic software modules and configure a freshly installed Linux. So far it supports Ubuntu and Manjaro Linux. It is tested on x86 and arm64.

# Instructions
To use the script do not clone the repository because the script is also intended to do the first time setup of git.
Instead, download the script with wget:
```shell
wget https://raw.githubusercontent.com/Lenz-K/setup-script/main/setup-script.sh
```
_Or copy the [content](https://github.com/Lenz-K/setup-script/blob/main/setup-script.sh)
into a file called `setup-script.sh` if wget is not available._

Then make it executable:
```shell
chmod a+x setup-script.sh
```
Finally, run it:
```shell
sudo ./setup-script.sh
```
Now follow the instructions of the script.

The three commands above can also be run as one command:
```shell
wget https://raw.githubusercontent.com/Lenz-K/setup-script/main/setup-script.sh && chmod a+x setup-script.sh && sudo ./setup-script.sh
```

# Features
The interactive script has three stages.
### 1. System Update
### 2. Install Selected Modules
The script asks to install the following software modules if not available:
- git
- python
- pip
- Docker Engine
- docker-compose
- cryptsetup  
_Note: Needed to mount or create encrypted devices._
- cifs-utils  
_Note: Needed to mount SMB network shared directories._
- ExpressVPN  
_Note: ExpressVPN is only supported on x86 systems._
- ufw (Uncomplicated Firewall)
- OpenSSH

### 3. Configurations
The script then asks to configure the following features
(The script dynamically determines which features make sense on a system):
- Automatic Updates
- Add a User
- git
- ExpressVPN
- Set Timezone to UTC
- ufw (Uncomplicated Firewall)
- Enforce SSH Key Authentication
