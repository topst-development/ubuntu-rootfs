#!/bin/bash

# APT updating
apt --fix-broken install -y || res=$?

echo "apt --fix-broken install"
if [ "${res}" = 1 ]; then
  echo "failed, apt --fix-broken install"
else
  echo "apt update"
  echo ""
  apt update -y || res=$?
  if [ "${res}" = 1 ]; then
    echo "failed, apt update"
  else
    echo "apt update"
    apt upgrade -y
  fi
fi

# Install xubuntu-desktop either lightdm or gdm3
# lightdm
#sudo DEBIAN_FRONTEND=noninteractive apt install -y xubuntu-desktop lightdm

#gdm3
apt --fix-broken install -y
DEBIAN_FRONTEND=noninteractive apt install -y xubuntu-desktop gdm3

# Enalbe Wayland
sed -i 's/#WaylandEnable=false/WaylandEnable=true/' /etc/gdm3/custom.conf
