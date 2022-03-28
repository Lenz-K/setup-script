#!/bin/bash

# Retrieve system information
ARCH=$(uname -m)
if [[ $ARCH == *"x86"* ]]; then
  ARCH="x86"
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

echo ""
echo "##########################"
echo "#       Selections       #"
echo "##########################"

# String for install command
MODULES_TO_INSTALL=""

read -p "Configure automatic updates at midnight? ([y]/n) " DO_AUTOMATIC_UPDATES
DO_AUTOMATIC_UPDATES=${DO_AUTOMATIC_UPDATES:-y}

read -p "Install and setup git? Required for ExpressVPN. ([y]/n) " DO_GIT
DO_GIT=${DO_GIT:-y}
if [ $DO_GIT = "y" ]; then
  MODULES_TO_INSTALL="$MODULES_TO_INSTALL git"
fi

read -p "Install python? Required for ExpressVPN. ([y]/n) " DO_PY
DO_PY=${DO_PY:-y}
if [ $DO_PY = "y" ]; then
  if [ $DISTRO = "Ubuntu" ]; then
    MODULES_TO_INSTALL="$MODULES_TO_INSTALL python3"
  elif [ $DISTRO = "Manjaro" ]; then
    MODULES_TO_INSTALL="$MODULES_TO_INSTALL python"
  fi
fi

if [ $DO_PY = "y" ]; then
  read -p "Install pip? ([y]/n) " DO_PIP
  DO_PIP=${DO_PIP:-y}
  if [ $DO_PIP = "y" ]; then
    if [ $DISTRO = "Ubuntu" ]; then
      MODULES_TO_INSTALL="$MODULES_TO_INSTALL python3-pip"
    elif [ $DISTRO = "Manjaro" ]; then
      MODULES_TO_INSTALL="$MODULES_TO_INSTALL python-pip"
    fi
  fi
fi

read -p "Install cryptsetup? ([y]/n) " DO_CRYPT
DO_CRYPT=${DO_CRYPT:-y}
if [ $DO_CRYPT = "y" ]; then
  MODULES_TO_INSTALL="$MODULES_TO_INSTALL cryptsetup"
fi

if [ $ARCH = "x86" ] && [ $DO_PY = "y" ] && [ $DO_GIT = "y" ]; then
  read -p "Install and setup ExpressVPN? ([y]/n) " DO_EXPRESS_VPN
  DO_EXPRESS_VPN=${DO_EXPRESS_VPN:-y}
else
  DO_EXPRESS_VPN="n"
fi


read -p "Install and setup ufw (Uncomplicated Firewall)? ([y]/n) " DO_UFW
DO_UFW=${DO_UFW:-y}
if [ $DO_UFW = "y" ]; then
  MODULES_TO_INSTALL="$MODULES_TO_INSTALL ufw"
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

if [ $DO_EXPRESS_VPN = "y" ]; then
  #git -C /usr/local/sbin clone update-expressvpn.py

  python update-expressvpn.py $DISTRO
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
      echo "5 0 * * * root python /usr/local/sbin/setup-script/update-expressvpn.py ${DISTRO}" >> /etc/cron.d/update-system-crontab
      echo "6 0 * * * root git -C /usr/local/sbin/setup-script pull" >> /etc/cron.d/update-system-crontab
    fi
  fi
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
    read -p "Allow SSH through firewall? ([y]/n) " DO_SSH
    DO_SSH=${DO_SSH:-y}
    if [ $DO_SSH = "y" ]; then
      ufw allow ssh
    fi
    if [ $DISTRO = "Manjaro" ]; then
      systemctl enable ufw
    fi
    ufw --force enable
  fi
fi

echo ""
echo "All done! Let's go!"
