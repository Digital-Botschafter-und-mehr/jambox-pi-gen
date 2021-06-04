
mkdir -p ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.config/aj-snapshot
cp files/*.xml ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.config/aj-snapshot

cp files/jack.service ${ROOTFS_DIR}/usr/lib/systemd/system/
