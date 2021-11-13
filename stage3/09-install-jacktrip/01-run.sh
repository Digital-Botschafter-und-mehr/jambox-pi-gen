# Install desktop shortcut.

mkdir -p ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/Desktop
cp files/Desktop/*.desktop ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/Desktop/
cp files/Desktop/*.desktop ${ROOTFS_DIR}/usr/share/applications/

echo "NoDisplay=true" >> ${ROOTFS_DIR}/usr/share/applications/jacktrip.desktop

cp files/jacktrip_start.sh ${ROOTFS_DIR}/usr/local/bin/
chmod +x ${ROOTFS_DIR}/usr/local/bin/jacktrip_start.sh

cp files/jacktrip_start.conf ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.config/

on_chroot << EOF
	ln -s /usr/bin/jackd /usr/bin/jackdmp
EOF
