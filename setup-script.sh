#!/bin/bash

echo ""
echo "##########################"
echo "#     System Updates     #"
echo "##########################"
apt update
apt -y upgrade

echo ""
echo "##########################"
echo "#       Selections       #"
echo "##########################"

# String for apt install
MODULES_TO_INSTALL=""

read -p "Configure automatic updates? ([y]/n) " DO_AUTOMATIC_UPDATES
DO_AUTOMATIC_UPDATES=${DO_AUTOMATIC_UPDATES:-y}

read -p "Install and setup git? ([y]/n) " DO_GIT
DO_GIT=${DO_GIT:-y}
if [ $DO_GIT = "y" ]; then
  MODULES_TO_INSTALL="$MODULES_TO_INSTALL git"
fi

read -p "Install python and pip? ([y]/n) " DO_PY
DO_PY=${DO_PY:-y}
if [ $DO_PY = "y" ]; then
  MODULES_TO_INSTALL="$MODULES_TO_INSTALL python3 python3-pip"
fi

read -p "Install cryptsetup? ([y]/n) " DO_CRYPT
DO_CRYPT=${DO_CRYPT:-y}
if [ $DO_CRYPT = "y" ]; then
  MODULES_TO_INSTALL="$MODULES_TO_INSTALL cryptsetup"
fi

read -p "Install and setup ExpressVPN? ([y]/n) " DO_EXPRESS_VPN
DO_EXPRESS_VPN=${DO_EXPRESS_VPN:-y}

echo ""
echo "##########################"
echo "# Package Installations  #"
echo "##########################"
if ! [[ -z $MODULES_TO_INSTALL ]]; then
  echo "Installing the following modules: $MODULES_TO_INSTALL"
  apt -y install $MODULES_TO_INSTALL
fi

if [ $DO_EXPRESS_VPN = "y" ]; then
  echo ""
  echo "Installing expressvpn..."
  EXPRESS_VPN_VERSION="expressvpn_3.20.0.5-1_amd64.deb"
  EXPECTED_FINGERPRINT="pub   rsa4096 2016-01-22 [SC]
      1D0B 09AD 6C93 FEE9 3FDD  BD9D AFF2 A141 5F6A 3A38
uid           [ unknown] ExpressVPN Release <release@expressvpn.com>
sub   rsa4096 2016-01-22 [E]"

  wget https://www.expressvpn.works/clients/linux/$EXPRESS_VPN_VERSION
  wget https://www.expressvpn.works/clients/linux/$EXPRESS_VPN_VERSION.asc

  gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys 0xAFF2A1415F6A3A38
  KEY_FINGERPRINT=$(gpg --fingerprint release@expressvpn.com)

  if [ "$KEY_FINGERPRINT" = "$EXPECTED_FINGERPRINT" ]; then
    gpg --verify $EXPRESS_VPN_VERSION.asc
    if [ $? -eq 0 ]; then
      dpkg -i $EXPRESS_VPN_VERSION
    else
      echo "Aborting ExpressVPN installation!"
      DO_EXPRESS_VPN="n"
    fi
  else
    echo "The fingerprint of the downloaded ExpressVPN key is not as expected!"
    echo "Aborting ExpressVPN installation!"
    DO_EXPRESS_VPN="n"
  fi
fi

echo ""
echo "##########################"
echo "#     Configurations     #"
echo "##########################"
if [ $DO_AUTOMATIC_UPDATES = "y" ]; then
  echo -e "#!/bin/bash\napt update\napt -y upgrade" >> /usr/local/bin/update-system.sh
  chmod a+x /usr/local/bin/update-system.sh
  echo "0 0 * * * root update-system.sh" >> /etc/cron.d/update-system-crontab
fi

if [ $DO_GIT = "y" ]; then
  read -p "Please enter your name for git: " NAME
  git config --global user.name "$NAME"

  read -p "Please enter your E-Mail for git: " EMAIL
  git config --global user.email $EMAIL

  read -p "Generate SSH key? ([y]/n) " DO_GENERATE_KEY
  DO_GENERATE_KEY=${DO_GENERATE_KEY:-y}
  if [ $DO_GENERATE_KEY = "y" ]; then
    echo "Generating SSH key..."
    ssh-keygen -t ed25519 -C $EMAIL
    echo "Instructions to add the SSH key to your GitHub profile can be found here: https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account"
  fi
fi

if [ $DO_PY = "y" ]; then
  ln -s python3 /usr/bin/python
fi

if [ $DO_EXPRESS_VPN = "y" ]; then
  expressvpn activate
  expressvpn autoconnect true
  expressvpn preferences set block_trackers true
  expressvpn connect
  read -p "Install ExpressVPN control add-on for Firefox? ([y]/n) " DO_FIREFOX
  DO_FIREFOX=${DO_FIREFOX:-y}
  if [ $DO_FIREFOX = "y" ]; then
    expressvpn install-firefox-extension
  fi
fi

read -p "Enable ufw (Uncomplicated Firewall)? ([y]/n) " DO_UFW
DO_UFW=${DO_UFW:-y}
if [ $DO_UFW = "y" ]; then
  read -p "Allow SSH through firewall? ([y]/n) " DO_SSH
  DO_SSH=${DO_SSH:-y}
  if [ $DO_SSH = "y" ]; then
    ufw allow ssh
  fi
  ufw --force enable
fi

echo ""
echo "All done! Let's go!"
