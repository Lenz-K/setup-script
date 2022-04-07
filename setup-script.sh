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

read -p "Configure automatic updates at midnight? ([y]/n) " DO_AUTOMATIC_UPDATES
DO_AUTOMATIC_UPDATES=${DO_AUTOMATIC_UPDATES:-y}
if [ $DO_AUTOMATIC_UPDATES = "y" ] && [ $DISTRO = "Manjaro" ]; then
  MODULES_TO_INSTALL="$MODULES_TO_INSTALL cronie"
fi

read -p "Install and setup git? Required for ExpressVPN. Not necessary if already installed. ([y]/n) " DO_GIT
DO_GIT=${DO_GIT:-y}
if [ $DO_GIT = "y" ]; then
  MODULES_TO_INSTALL="$MODULES_TO_INSTALL git"
fi

read -p "Install python? Required for ExpressVPN. Not necessary if already installed. ([y]/n) " DO_PY
DO_PY=${DO_PY:-y}
if [ $DO_PY = "y" ]; then
  if [ $DISTRO = "Ubuntu" ]; then
    MODULES_TO_INSTALL="$MODULES_TO_INSTALL python3"
  elif [ $DISTRO = "Manjaro" ]; then
    MODULES_TO_INSTALL="$MODULES_TO_INSTALL python"
  fi
fi

read -p "Install pip? ([y]/n) " DO_PIP
DO_PIP=${DO_PIP:-y}
if [ $DO_PIP = "y" ]; then
  if [ $DISTRO = "Ubuntu" ]; then
    MODULES_TO_INSTALL="$MODULES_TO_INSTALL python3-pip"
  elif [ $DISTRO = "Manjaro" ]; then
    MODULES_TO_INSTALL="$MODULES_TO_INSTALL python-pip"
  fi
fi

read -p "Install Docker Engine? ([y]/n) " DO_DOCKER
DO_DOCKER=${DO_DOCKER:-y}
if [ $DO_DOCKER = "y" ]; then
  if [ $DISTRO = "Ubuntu" ]; then
    MODULES_TO_INSTALL="$MODULES_TO_INSTALL ca-certificates curl gnupg lsb-release"
  elif [ $DISTRO = "Manjaro" ]; then
    MODULES_TO_INSTALL="$MODULES_TO_INSTALL docker"
  fi
fi

read -p "Install cryptsetup? Needed to mount or create encrypted devices. ([y]/n) " DO_CRYPT
DO_CRYPT=${DO_CRYPT:-y}
if [ $DO_CRYPT = "y" ]; then
  MODULES_TO_INSTALL="$MODULES_TO_INSTALL cryptsetup"
fi

read -p "Install cifs-utils? Needed to mount SMB network shared directories. ([y]/n) " DO_CIFS
DO_CIFS=${DO_CIFS:-y}
if [ $DO_CIFS = "y" ]; then
  MODULES_TO_INSTALL="$MODULES_TO_INSTALL cifs-utils"
fi

if [ $ARCH = "x86" ]; then
  read -p "Install and setup ExpressVPN? ([y]/n) " DO_EXPRESS_VPN
  DO_EXPRESS_VPN=${DO_EXPRESS_VPN:-y}
  if [ $DO_EXPRESS_VPN = "y" ]; then
    MODULES_TO_INSTALL="$MODULES_TO_INSTALL wget"
  fi
else
  DO_EXPRESS_VPN="n"
fi

read -p "Install and setup ufw (Uncomplicated Firewall)? ([y]/n) " DO_UFW
DO_UFW=${DO_UFW:-y}
if [ $DO_UFW = "y" ]; then
  MODULES_TO_INSTALL="$MODULES_TO_INSTALL ufw"
fi

read -p "Install and configure openssh? ([y]/n) " DO_SSH
DO_SSH=${DO_SSH:-y}
if [ $DO_SSH = "y" ]; then
  if [ $DISTRO = "Ubuntu" ]; then
    MODULES_TO_INSTALL="$MODULES_TO_INSTALL openssh-server"
  elif [ $DISTRO = "Manjaro" ]; then
    MODULES_TO_INSTALL="$MODULES_TO_INSTALL openssh"
  fi
fi

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

if [ $DO_PY = "y" ] && [ $DISTRO = "Ubuntu" ]; then
  ln --symbolic --force python3 /usr/bin/python
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
if [ $DO_AUTOMATIC_UPDATES = "y" ]; then
  if [ $DISTRO = "Ubuntu" ] && [ ! -f /usr/local/sbin/update-system ]; then
    echo -e "#!/bin/bash\napt update\napt -y upgrade" >> /usr/local/sbin/update-system
  elif [ $DISTRO = "Manjaro" ] && [ ! -f /usr/local/sbin/update-system ]; then
    echo -e "#!/bin/bash\npacman -Syu --noconfirm" >> /usr/local/sbin/update-system
  fi
  chmod a+x /usr/local/sbin/update-system
  if [ ! -f /etc/cron.d/update-system-crontab ] || [[ $(cat /etc/cron.d/update-system-crontab) != *"0 0 * * * root /usr/local/sbin/update-system"* ]]; then
    echo "0 0 * * * root /usr/local/sbin/update-system" >> /etc/cron.d/update-system-crontab
  fi
  if [ $DO_EXPRESS_VPN = "y" ]; then
    if [ ! -f /etc/cron.d/update-system-crontab ] || [[ $(cat /etc/cron.d/update-system-crontab) != *"5 0 * * * root python /usr/local/sbin/setup-script/update-expressvpn.py"* ]]; then
      echo "5 0 * * * root git -C /usr/local/sbin/setup-script pull" >> /etc/cron.d/update-system-crontab
      echo "6 0 * * * root python /usr/local/sbin/setup-script/update-expressvpn.py ${DISTRO}" >> /etc/cron.d/update-system-crontab
    fi
  fi
fi

read -p "Add additional user? ([y]/n) " DO_CREATE_USER
DO_CREATE_USER=${DO_CREATE_USER:-y}
if [ $DO_CREATE_USER = "y" ]; then
  read -p "Enter the name of the new user: " NEW_USER
  useradd --create-home $NEW_USER -s /bin/bash
  passwd $NEW_USER
fi

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

if [ $DO_EXPRESS_VPN = "y" ]; then
  expressvpn activate
  expressvpn autoconnect true
  expressvpn preferences set block_trackers true
  expressvpn connect
fi

if [ $DO_UFW = "y" ]; then
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

if [ $DO_SSH = "y" ]; then
  echo ""
  echo "Enforce SSH key authentication?"
  echo "That means you must have already copied your SSH key to this machine."
  echo "If not run 'ssh-copy-id username@this_machine' on your machine."
  read -p "Enforce SSH key authentication? ([y]/n) " DO_SSH_AUTH
  DO_SSH_AUTH=${DO_SSH_AUTH:-y}

  if [ $DO_SSH_AUTH = "y" ]; then
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
