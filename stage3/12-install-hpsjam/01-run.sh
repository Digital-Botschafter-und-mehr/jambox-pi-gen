
mkdir -p ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/Desktop
cp files/Desktop/*.desktop ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/Desktop/
cp files/Desktop/*.desktop ${ROOTFS_DIR}/usr/share/applications/
cp files/HpsJam_bw.png ${ROOTFS_DIR}/usr/share/icons/

cp files/hpsjam_start.sh ${ROOTFS_DIR}/usr/local/bin/
chmod +x ${ROOTFS_DIR}/usr/local/bin/hpsjam_start.sh
cp files/hpsjam_start.conf ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.config/
cp files/HpsJam.conf ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.config/

echo "NoDisplay=true" >> ${ROOTFS_DIR}/usr/share/applications/HpsJam.desktop

# install hpsjam-server files
cp files/hpsjam-server.service ${ROOTFS_DIR}/usr/lib/systemd/system/
cp files/hpsjam-server.conf ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.config/
