# Install desktop shortcut.

JAMMERNETZ_CONFIG_DIR=home/${FIRST_USER_NAME}/JammerNetz

mkdir -p ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/Desktop
cp files/Desktop/*.desktop ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/Desktop/
cp files/Desktop/*.desktop ${ROOTFS_DIR}/usr/share/applications/
cp files/*.png ${ROOTFS_DIR}/usr/share/icons

cp files/jammernetz_start.sh ${ROOTFS_DIR}/usr/local/bin/
chmod +x ${ROOTFS_DIR}/usr/local/bin/jammernetz_start.sh

mkdir -p ${ROOTFS_DIR}/$JAMMERNETZ_CONFIG_DIR
mkdir -p ${ROOTFS_DIR}/boot/payload/$JAMMERNETZ_CONFIG_DIR
cp files/zeros.bin ${ROOTFS_DIR}/${JAMMERNETZ_CONFIG_DIR}/
# allow custom build version by defining:
#   export CUSTOM_VERSION=<custom_version_name>
# and placing customized files in directory:
#   stage3/11-install-jammernetz/files/${CUSTOM_VERSION}/
# customized files may include:
#   jammernetz_start.conf

# install jammernetz-server files
cp files/jammernetz-server.service ${ROOTFS_DIR}/usr/lib/systemd/system/
cp files/jammernetz-server.conf ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/JammerNetz/

if [[ -n "$CUSTOM_VERSION" ]]; then
  if [[ -f files/${CUSTOM_VERSION}/jammernetz_start.conf ]]; then
    cp files/${CUSTOM_VERSION}/jammernetz_start.conf ${ROOTFS_DIR}/boot/payload/${JAMMERNETZ_CONFIG_DIR}/
    cp files/${CUSTOM_VERSION}/jammernetz_start.conf ${ROOTFS_DIR}/${JAMMERNETZ_CONFIG_DIR}/
  else
    cp files/jammernetz_start.conf ${ROOTFS_DIR}/boot/payload/${JAMMERNETZ_CONFIG_DIR}/
    cp files/jammernetz_start.conf ${ROOTFS_DIR}/${JAMMERNETZ_CONFIG_DIR}/
  fi
  if [[ -f files/${CUSTOM_VERSION}/JammerNetz.settings ]]; then
    cp files/${CUSTOM_VERSION}/JammerNetz.settings ${ROOTFS_DIR}/boot/payload/${JAMMERNETZ_CONFIG_DIR}/
    cp files/${CUSTOM_VERSION}/JammerNetz.settings ${ROOTFS_DIR}/${JAMMERNETZ_CONFIG_DIR}/
  else
    cp files/JammerNetz.settings ${ROOTFS_DIR}/boot/payload/${JAMMERNETZ_CONFIG_DIR}/
    cp files/JammerNetz.settgins ${ROOTFS_DIR}/${JAMMERNETZ_CONFIG_DIR}/
  fi
else
  cp files/jammernetz_start.conf ${ROOTFS_DIR}/boot/payload/${JAMMERNETZ_CONFIG_DIR}/
  cp files/jammernetz_start.conf ${ROOTFS_DIR}/${JAMMERNETZ_CONFIG_DIR}/
  cp files/JammerNetz.settings ${ROOTFS_DIR}/boot/payload/${JAMMERNETZ_CONFIG_DIR}/
  cp files/JammerNetz.settings ${ROOTFS_DIR}/${JAMMERNETZ_CONFIG_DIR}/
fi
