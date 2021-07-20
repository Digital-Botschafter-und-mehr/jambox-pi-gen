#!/bin/bash -e

# limit repos to arch=armhf except for jambox-project (for 64-bit kernel)
sed -i 's|^deb http|deb [ arch=armhf ] http|g' ${ROOTFS_DIR}/etc/apt/sources.list
sed -i 's|^deb http|deb [ arch=armhf ] http|g' ${ROOTFS_DIR}/etc/apt/sources.list.d/raspi.list

install -m 644 files/jambox-project.list ${ROOTFS_DIR}/etc/apt/sources.list.d/

on_chroot apt-key add - < files/repo.jambox-project.com.gpg
on_chroot << EOF
dpkg --add-architecture arm64
apt-get clean

# workaround broken raspberry pi mirrors
#apt-get update
apt -y install python3-pip python3-setuptools python3-wheel
pip3 install apt-smart
apt-smart -c http://mirror.us.leaseweb.net/raspbian/raspbian
apt-smart --max=1 --update-package-lists
EOF
