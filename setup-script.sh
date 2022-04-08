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
echo ""
echo "##########################"
echo "#     System Updates     #"
echo "##########################"
if [ $DISTRO = "Ubuntu" ]; then
  apt update
  apt -y upgrade
elif [ $DISTRO = "Manjaro" ]; then
  pacman -Syu --noconfirm
fi

read -p "Restart now? Recommended if a lot of updates were installed. ([y]/n) " DO_RESTART
DO_RESTART=${DO_RESTART:-y}
if [ $DO_RESTART = "y" ]; then
  reboot
fi

echo ""
echo "##########################"
echo "#       Selections       #"
echo "##########################"

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

# Asks for the installation of a module if not installed.
# The question defaults to "y". Adds module name to $MODULES_TO_INSTALL.
# Arguments:
# $1: Exists var
# $2: Question
# $3: Ubuntu package name
# $4: (Optional) Manjaro package name if different than $3
check_install () {
  # If the program is not installed
  if [ $1 = "n" ]; then
    # Ask for installation
    read -p "$2" DO_INSTALL
    # Default to "y"
    DO_INSTALL=${DO_INSTALL:-y}
    if [ $DO_INSTALL = "y" ]; then
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
  if [ -f /etc/cron.d/update-system-crontab ]; then
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
      $EXISTS_PYTHON = "y"
    fi
  elif [ $DISTRO = "Manjaro" ]; then
    EXISTS_PYTHON=$(command_exists python)
  fi

  EXISTS_PIP=$(command_exists pip)
  EXISTS_DOCKER=$(command_exists docker)
  EXISTS_CRYPT=$(command_exists cryptsetup)
  EXISTS_CIFS=$(command_exists cifs-utils)
  EXISTS_EXPRESS_VPN=$(command_exists expressvpn)
  EXISTS_WGET=$(command_exists wget)
  EXISTS_UFW=$(command_exists ufw)
  EXISTS_OPEN_SSH=$(command_exists sshd)
}

check_availabilities

if [ $EXISTS_AUTO_UPDATES = "n"]
  read -p "Configure automatic updates at midnight? ([y]/n) " DO_AUTOMATIC_UPDATES
  DO_AUTOMATIC_UPDATES=${DO_AUTOMATIC_UPDATES:-y}
  if [ $DO_AUTOMATIC_UPDATES = "y" ] && [ $EXISTS_CRON = "n" ]; then
    if [ $DISTRO = "Ubuntu" ]; then
      MODULES_TO_INSTALL="$MODULES_TO_INSTALL cron"
    elif [ $DISTRO = "Manjaro" ]; then
      MODULES_TO_INSTALL="$MODULES_TO_INSTALL cronie"
    fi
  fi
fi

check_install $EXISTS_GIT "Install git? ([y]/n) " "git"

check_install $EXISTS_PYTHON "Install python? ([y]/n) " "python3" "python"

check_install $EXISTS_PIP "Install pip? ([y]/n) " "python3-pip" "python-pip"

check_install $EXISTS_DOCKER "Install Docker Engine? ([y]/n) " "ca-certificates curl gnupg lsb-release" "docker"

check_install $EXISTS_CRYPT "Install cryptsetup? Needed to mount or create encrypted devices. ([y]/n) " "cryptsetup"

check_install $EXISTS_CIFS "Install cifs-utils? Needed to mount SMB network shared directories. ([y]/n) " "cifs-utils"

if [ $ARCH = "x86" ]; then
  check_install $EXISTS_EXPRESS_VPN "Install ExpressVPN? ([y]/n) " "wget"
fi

check_install $EXISTS_UFW "Install ufw (Uncomplicated Firewall)? ([y]/n) " "ufw"

check_install $EXISTS_OPEN_SSH "Install openssh? ([y]/n) " "openssh-server" "openssh"

echo ""
echo "##########################"
echo "# Package Installations  #"
echo "##########################"
if ! [[ -z $MODULES_TO_INSTALL ]]; then
  echo "Installing the following modules: $MODULES_TO_INSTALL"
  if [ $DISTRO = "Ubuntu" ]; then
    apt -y install $MODULES_TO_INSTALL
  elif [ $DISTRO = "Manjaro" ]; then
    pacman -S --noconfirm --needed $MODULES_TO_INSTALL
  fi
fi

if [ $DO_DOCKER = "y" ]; then
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

  read -p "Add user to group 'docker'? ([y]/n) " DO_ADD_GROUP
  DO_ADD_GROUP=${DO_ADD_GROUP:-y}
  if [ $DO_ADD_GROUP = "y" ]; then
    read -p "Enter the name of the user? " USERNAME
    usermod -aG docker $USERNAME
  fi
fi

if [ $DO_EXPRESS_VPN = "y" ]; then
  # Clone this repository to get the script that updates ExpressVPN
  if [ ! -d /usr/local/sbin/setup-script ]; then
    git -C /usr/local/sbin clone https://github.com/Lenz-K/setup-script.git
  fi

  python /usr/local/sbin/setup-script/update-expressvpn.py $DISTRO
  if [ $? -ne 0 ]; then
    DO_EXPRESS_VPN="n"
  fi
fi

echo ""
echo "##########################"
echo "#     Configurations     #"
echo "##########################"

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
  if [ $DO_EXPRESS_VPN = "y" ]; then
    write_crontab_no_duplicate "5 0 * * * root git -C /usr/local/sbin/setup-script pull"
    write_crontab_no_duplicate "6 0 * * * root python /usr/local/sbin/setup-script/update-expressvpn.py ${DISTRO}"
  fi
fi

read -p "Add additional user? ([y]/n) " DO_CREATE_USER
DO_CREATE_USER=${DO_CREATE_USER:-y}
if [ $DO_CREATE_USER = "y" ]; then
  read -p "Enter the name of the new user: " NEW_USER
  useradd --create-home $NEW_USER -s /bin/bash
  passwd $NEW_USER
fi

if [ $EXISTS_GIT = "y" ]; then
  read -p "Do first time setup for git? ([y]/n) " DO_GIT
  DO_GIT=${DO_GIT:-y}
  if [ $DO_GIT = "y" ]; then
    read -p "Please enter your name for git: " NAME
    git config --global user.name "$NAME"

    read -p "Please enter your E-Mail for git: " EMAIL
    git config --global user.email $EMAIL

    read -p "Generate SSH key? ([y]/n) " DO_GENERATE_KEY
    DO_GENERATE_KEY=${DO_GENERATE_KEY:-y}
    if [ $DO_GENERATE_KEY = "y" ]; then
      read -p "For which user shall the SSH key be generated? [root] " KEY_FOR_USER
      KEY_FOR_USER=${KEY_FOR_USER:-root}
      echo "Generating SSH key..."
      su -c "ssh-keygen -t ed25519 -C $EMAIL" $KEY_FOR_USER
      echo "Instructions to add the SSH key to your GitHub profile can be found here: https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account"
    fi
  fi
fi

if [ $EXISTS_EXPRESS_VPN = "y" ]; then
  read -p "Do ExpressVPN setup? ([y]/n) " DO_EXPRESS_VPN
  DO_EXPRESS_VPN=${DO_EXPRESS_VPN:-y}
  if [ $DO_EXPRESS_VPN = "y" ]; then
    expressvpn activate
    expressvpn autoconnect true
    expressvpn preferences set block_trackers true
    expressvpn connect
  fi
fi

if [ $EXISTS_UFW = "y" ]; then
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

if [ $EXISTS_OPEN_SSH = "y" ] && [[ $(cat /etc/ssh/sshd_config) != *"PasswordAuthentication yes"* ]] && [[ $(cat /etc/ssh/sshd_config) != *"#PasswordAuthentication no"* ]]; then
  echo ""
  echo "Enforce SSH key authentication?"
  echo "That means you must have already copied your SSH key to this machine."
  echo "If not run 'ssh-copy-id username@this_machine' on your machine."
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

echo ""
echo "All done! Let's go!"
