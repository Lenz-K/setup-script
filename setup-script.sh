#!/bin/bash

if [ $EUID -ne 0 ]; then
  echo "Please run as root"
  exit 0
fi

# Retrieve system information
ARCH=$(uname -m)
if [[ $ARCH == *"x86"* ]]; then
  ARCH="x86"
elif [[ $ARCH == *"aarch64"* ]]; then
  ARCH="aarch64"
  echo "ExpressVPN is not supported on arm64 and will be ignored."
else
  ARCH="Unsupported"
  echo "Unsupported processor architecture! Some features of this script are ignored."
fi

DISTRO=$(cat /etc/issue)
if [[ $DISTRO == *"Ubuntu"* ]]; then
  DISTRO="Ubuntu"
elif [[ $DISTRO == *"Manjaro"* ]] ; then
  DISTRO="Manjaro"
else
  echo "Unsupported Linux distribution!"
  exit 0
fi

echo "Detected system: $ARCH architecture - $DISTRO OS"
echo """
 _   _  ___  ___   ___  _____  ___  ___
| | | || _ \|   \ /   \|_   _|| __|/ __|
| |_| ||  _/| |) || - |  | |  | _| \__ \\
 \___/ |_|  |___/ |_|_|  |_|  |___||___/
========================================"""


if [ $DISTRO = "Ubuntu" ]; then
  apt update
  apt -y upgrade
elif [ $DISTRO = "Manjaro" ]; then
  pacman -Syu --noconfirm
fi

echo ""
read -p "Restart now? Recommended if a lot of updates were installed. ([y]/n) " DO_RESTART
DO_RESTART=${DO_RESTART:-y}
if [ $DO_RESTART = "y" ]; then
  reboot
fi

echo """
 ___  ___  _     ___   ___  _____  ___   ___   _  _  ___
/ __|| __|| |   | __| / __||_   _||_ _| / _ \ | \| |/ __|
\__ \| _| | |__ | _| | (__   | |   | | | (_) || .  |\__ \\
|___/|___||____||___| \___|  |_|  |___| \___/ |_|\_||___/
========================================================="""

# String for install command
MODULES_TO_INSTALL=""

# Provide a command as first argument to check its existence.
# Echoes 'y' if available, 'n' if not available.
command_exists () {
  if command -v $1 &> /dev/null; then
    echo "y"
  else
    echo "n"
  fi
}

# Asks for the installation of a module if not installed and writes the result int $RES.
# The question defaults to "y". Adds module name to $MODULES_TO_INSTALL.
# Arguments:
# $1: Exists var
# $2: Question
# $3: Ubuntu package name
# $4: (Optional) Manjaro package name if different than $3
check_install () {
  # If the program is not installed
  RES="n"
  if [ $1 = "n" ]; then
    # Ask for installation
    read -p "$2 ([y]/n) " DO_INSTALL
    # Default to "y"
    DO_INSTALL=${DO_INSTALL:-y}
    if [ $DO_INSTALL = "y" ]; then
      RES="y"
      # If a fourth argument is given differentiate between distros
      if [ -z $4 ]; then
        MODULES_TO_INSTALL="$MODULES_TO_INSTALL $3"
      else
        if [ $DISTRO = "Ubuntu" ]; then
          MODULES_TO_INSTALL="$MODULES_TO_INSTALL $3"
        elif [ $DISTRO = "Manjaro" ]; then
          MODULES_TO_INSTALL="$MODULES_TO_INSTALL $4"
        fi
      fi
    fi
  fi
}

check_availabilities () {
  EXISTS_EXPRESS_VPN=$(command_exists expressvpn)

  if [ -f /etc/cron.d/update-system-crontab ] && \
     [[ $(cat /etc/cron.d/update-system-crontab) == *"0 0 * * * root /usr/local/sbin/update-system"* ]] && \
     [[ $(cat /etc/cron.d/update-system-crontab) == *"6 0 * * * root python /usr/local/sbin/setup-script/update-expressvpn.py ${DISTRO}"* || $EXISTS_EXPRESS_VPN == "n" ]]; then
    EXISTS_AUTO_UPDATES="y"
  else
    EXISTS_AUTO_UPDATES="n"
  fi

  EXISTS_CRON=$(command_exists crontab)
  EXISTS_GIT=$(command_exists git)

  if [ $DISTRO = "Ubuntu" ]; then
    EXISTS_PYTHON=$(command_exists python)
    EXISTS_PYTHON3=$(command_exists python3)
    if [ $EXISTS_PYTHON3 = "y" ] && [ $EXISTS_PYTHON = "n" ]; then
      ln --symbolic --force python3 /usr/bin/python
      EXISTS_PYTHON="y"
    fi
  elif [ $DISTRO = "Manjaro" ]; then
    EXISTS_PYTHON=$(command_exists python)
  fi

  EXISTS_PIP=$(command_exists pip)
  EXISTS_DOCKER=$(command_exists docker)
  EXISTS_DOCKER_COMPOSE=$(command_exists docker-compose)
  EXISTS_CRYPT=$(command_exists cryptsetup)
  EXISTS_CIFS=$(command_exists mount.cifs)
  EXISTS_WGET=$(command_exists wget)
  EXISTS_TIMEDATECTL=$(command_exists timedatectl)
  EXISTS_UFW=$(command_exists ufw)
  EXISTS_OPEN_SSH=$(command_exists sshd)
}

check_availabilities

check_install $EXISTS_GIT "Install git?" "git"

check_install $EXISTS_PYTHON "Install python?" "python3" "python"

check_install $EXISTS_PIP "Install pip?" "python3-pip" "python-pip"

if [ $DISTRO = "Ubuntu" ]; then
  dpkg -s python3.9-venv &> /dev/null
  if [ $? -ne 0 ]; then
    read -p "Install python module for virtual environments (venv)? ([y]/n) " INSTALL_VENV
    INSTALL_VENV=${INSTALL_VENV:-y}
    if [ $INSTALL_VENV = "y" ]; then
      MODULES_TO_INSTALL="$MODULES_TO_INSTALL python3.9-venv"
    fi
  fi
fi

check_install $EXISTS_DOCKER "Install Docker Engine?" "ca-certificates curl gnupg lsb-release" "docker"
INSTALL_DOCKER=$RES

if [ $EXISTS_DOCKER = "y" ] || [ $INSTALL_DOCKER = "y" ]; then
  check_install $EXISTS_DOCKER_COMPOSE "Install docker-compose?" "curl" "docker-compose"
  INSTALL_DOCKER_COMPOSE=$RES
else
  INSTALL_DOCKER_COMPOSE="n"
fi

check_install $EXISTS_CRYPT "Install cryptsetup? Needed to mount or create encrypted devices." "cryptsetup"

check_install $EXISTS_CIFS "Install cifs-utils? Needed to mount SMB network shared directories." "cifs-utils"

if [ $ARCH = "x86" ]; then
  check_install $EXISTS_EXPRESS_VPN "Install ExpressVPN?" "wget"
  INSTALL_EXPRESS_VPN=$RES
else
  INSTALL_EXPRESS_VPN="n"
fi

check_install $EXISTS_UFW "Install ufw (Uncomplicated Firewall)?" "ufw"

check_install $EXISTS_OPEN_SSH "Install openssh?" "openssh-server" "openssh"

if [ $EXISTS_AUTO_UPDATES = "n" ] || [ $INSTALL_EXPRESS_VPN = "y" ]; then
  read -p "Configure automatic updates at midnight? ([y]/n) " DO_AUTOMATIC_UPDATES
  DO_AUTOMATIC_UPDATES=${DO_AUTOMATIC_UPDATES:-y}
  if [ $DO_AUTOMATIC_UPDATES = "y" ] && [ $EXISTS_CRON = "n" ]; then
    if [ $DISTRO = "Ubuntu" ]; then
      MODULES_TO_INSTALL="$MODULES_TO_INSTALL cron"
    elif [ $DISTRO = "Manjaro" ]; then
      MODULES_TO_INSTALL="$MODULES_TO_INSTALL cronie"
    fi
  fi
else
  DO_AUTOMATIC_UPDATES="n"
fi

echo """
 ___  _  _  ___  _____  ___  _     _
|_ _|| \| |/ __||_   _|/   \| |   | |
 | | | .  |\__ \  | |  | - || |__ | |__
|___||_|\_||___/  |_|  |_|_||____||____|
========================================"""

if ! [[ -z $MODULES_TO_INSTALL ]]; then
  echo "Installing the following modules: $MODULES_TO_INSTALL"
  if [ $DISTRO = "Ubuntu" ]; then
    apt -y install $MODULES_TO_INSTALL
  elif [ $DISTRO = "Manjaro" ]; then
    pacman -S --noconfirm --needed $MODULES_TO_INSTALL
  fi
fi

if [ $INSTALL_DOCKER = "y" ]; then
  if [ $DISTRO = "Ubuntu" ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt -y install docker-ce docker-ce-cli containerd.io
  elif [ $DISTRO = "Manjaro" ]; then
    systemctl start docker.service
    systemctl enable docker.service
  fi
fi

if [ $INSTALL_DOCKER_COMPOSE = "y" ] && [ $DISTRO = "Ubuntu" ]; then
  INSTALL_PATH=/usr/local/lib/docker
  mkdir -p $INSTALL_PATH/cli-plugins
  curl -SL https://github.com/docker/compose/releases/download/v2.2.3/docker-compose-$(uname -s)-$(uname -m) -o $INSTALL_PATH/cli-plugins/docker-compose
  chmod +x $INSTALL_PATH/cli-plugins/docker-compose
  ln --symbolic --force $INSTALL_PATH/cli-plugins/docker-compose /usr/bin/docker-compose
fi

if [ $INSTALL_EXPRESS_VPN = "y" ]; then
  # Clone this repository to get the script that updates ExpressVPN
  if [ ! -d /usr/local/sbin/setup-script ]; then
    git -C /usr/local/sbin clone https://github.com/Lenz-K/setup-script.git
  fi

  python /usr/local/sbin/setup-script/update-expressvpn.py $DISTRO
  if [ $? -ne 0 ]; then
    DO_EXPRESS_VPN="n"
  fi
fi

echo """
  ___   ___   _  _  ___  ___   ___  _   _  ___  ___  _____  ___   ___   _  _  ___
 / __| / _ \ | \| || __||_ _| / __|| | | || _ \/   \|_   _||_ _| / _ \ | \| |/ __|
| (__ | (_) || .  || _|  | | | (_ || |_| ||   /| - |  | |   | | | (_) || .  |\__ \\
 \___| \___/ |_|\_||_|  |___| \___| \___/ |_|_\|_|_|  |_|  |___| \___/ |_|\_||___/
=================================================================================="""

check_availabilities

# Write text to /etc/cron.d/update-system-crontab after checking that the text does not yet exist
# Arguments: $1: Text to write
write_crontab_no_duplicate () {
  if [ ! -f /etc/cron.d/update-system-crontab ] || [[ $(cat /etc/cron.d/update-system-crontab) != *"$1"* ]]; then
    echo "$1" >> /etc/cron.d/update-system-crontab
  fi
}

if [ $DO_AUTOMATIC_UPDATES = "y" ]; then
  if [ $DISTRO = "Ubuntu" ] && [ ! -f /usr/local/sbin/update-system ]; then
    echo -e "#!/bin/bash\napt update\napt -y upgrade" >> /usr/local/sbin/update-system
  elif [ $DISTRO = "Manjaro" ] && [ ! -f /usr/local/sbin/update-system ]; then
    echo -e "#!/bin/bash\npacman -Syu --noconfirm" >> /usr/local/sbin/update-system
  fi
  chmod a+x /usr/local/sbin/update-system
  write_crontab_no_duplicate "0 0 * * * root /usr/local/sbin/update-system"
  if [ $EXISTS_EXPRESS_VPN = "y" ]; then
    write_crontab_no_duplicate "5 0 * * * root git -C /usr/local/sbin/setup-script pull"
    write_crontab_no_duplicate "6 0 * * * root python /usr/local/sbin/setup-script/update-expressvpn.py ${DISTRO}"
  fi
fi

echo ""
read -p "Add an additional user? ([y]/n) " DO_CREATE_USER
DO_CREATE_USER=${DO_CREATE_USER:-y}
if [ $DO_CREATE_USER = "y" ]; then
  read -p "Enter the name of the new user: " NEW_USER
  useradd --create-home $NEW_USER -s /bin/bash
  passwd $NEW_USER
  read -p "Add user ${NEW_USER} to sudoers? ([y]/n) " DO_SUDO
  DO_SUDO=${DO_SUDO:-y}
  if [ $DO_SUDO = "y" ]; then
    if [ $DISTRO = "Ubuntu" ]; then
      usermod -aG sudo $NEW_USER
    elif [ $DISTRO = "Manjaro" ]; then
      usermod -aG wheel $NEW_USER
    fi
  fi
fi

if [ $EXISTS_GIT = "y" ]; then
  echo ""
  read -p "Do first time setup for git? ([y]/n) " DO_GIT
  DO_GIT=${DO_GIT:-y}
  if [ $DO_GIT = "y" ]; then
    read -p "For which user shall git be set up? [root] " USER_NAME
    USER_NAME=${USER_NAME:-root}

    read -p "Please enter your name for git: " NAME
    su -c "git config --global user.name \"${NAME}\"" $USER_NAME

    read -p "Please enter your E-Mail for git: " EMAIL
    su -c "git config --global user.email \"${EMAIL}\"" $USER_NAME

    read -p "Generate SSH key? ([y]/n) " DO_GENERATE_KEY
    DO_GENERATE_KEY=${DO_GENERATE_KEY:-y}
    if [ $DO_GENERATE_KEY = "y" ]; then
      echo "Generating SSH key..."
      su -c "ssh-keygen -t ed25519 -C $EMAIL" $USER_NAME
      echo """Instructions to add the SSH key to your GitHub profile can be found here:
https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account"""
    fi
  fi
fi

if [ $INSTALL_DOCKER = "y" ]; then
  echo ""
  read -p "Add a user to group 'docker'? ([y]/n) " DO_ADD_GROUP
  DO_ADD_GROUP=${DO_ADD_GROUP:-y}
  if [ $DO_ADD_GROUP = "y" ]; then
    read -p "Enter the name of the user? " USERNAME
    usermod -aG docker $USERNAME
  fi
fi

if [ $EXISTS_EXPRESS_VPN = "y" ]; then
  echo ""
  read -p "Do ExpressVPN setup? ([y]/n) " DO_EXPRESS_VPN
  DO_EXPRESS_VPN=${DO_EXPRESS_VPN:-y}
  if [ $DO_EXPRESS_VPN = "y" ]; then
    expressvpn activate
    expressvpn autoconnect true
    expressvpn preferences set block_trackers true
    expressvpn connect
  fi
fi

if [ $EXISTS_TIMEDATECTL = "y" ]; then
  echo ""
  read -p "Set timezone to UTC? ([y]/n) " DO_SET_UTC
  DO_SET_UTC=${DO_SET_UTC:-y}
  if [ $DO_SET_UTC = "y" ]; then
    timedatectl set-timezone UTC
  fi
fi

if [ $EXISTS_UFW = "y" ] && [[ $(ufw status) == "Status: inactive" ]]; then
  echo ""
  read -p "Enable ufw (Uncomplicated Firewall)? ([y]/n) " ACTIVATE_UFW
  ACTIVATE_UFW=${ACTIVATE_UFW:-y}
  if [ $ACTIVATE_UFW = "y" ]; then
    read -p "Allow SSH through firewall? ([y]/n) " ALLOW_SSH
    ALLOW_SSH=${ALLOW_SSH:-y}
    if [ $ALLOW_SSH = "y" ]; then
      ufw allow ssh
    fi
    if [ $DISTRO = "Manjaro" ]; then
      systemctl enable ufw
    fi
    ufw --force enable
  fi
fi

if [ $EXISTS_OPEN_SSH = "y" ] && \
   [[ $(cat /etc/ssh/sshd_config) == *"PasswordAuthentication yes"* || $(cat /etc/ssh/sshd_config) == *"#PasswordAuthentication no"* ]]; then
  echo ""
  echo "Enforce SSH key authentication?"
  echo "That means if you are connected to this machine via SSH you must have already copied your SSH key to this machine."
  echo "If not run 'ssh-copy-id username@this_machine' on your local machine."
  read -p "Enforce SSH key authentication? ([y]/n) " DO_SSH_AUTH
  DO_SSH_AUTH=${DO_SSH_AUTH:-y}

  if [ $DO_SSH_AUTH = "y" ]; then
    sed -i "s/#PasswordAuthentication no/PasswordAuthentication no/" /etc/ssh/sshd_config
    sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
    sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
    systemctl restart sshd.service
    if [ $DISTRO = "Manjaro" ]; then
      systemctl enable sshd.service
    fi
  fi
fi

echo """
 ___  _     _           ___    ___   _  _  ___   _
/   \| |   | |         |   \  / _ \ | \| || __| | |
| - || |__ | |__       | |) || (_) || .  || _|  |_|
|_|_||____||____|      |___/  \___/ |_|\_||___| (_)

                      __
                      \  \\
                      |   |
                     /    /_____
                 ___/      |____|
                           |____|
                 ___       |___/
                    \_____/___/

 _     ___  _____  ( )  ___         ___   ___    _
| |   | __||_   _|  \| / __|       / __| / _ \  | |
| |__ | _|   | |       \__ \      | (_ || (_) | |_|
|____||___|  |_|       |___/       \___| \___/  (_)
"""
