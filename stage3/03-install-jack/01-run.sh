
mkdir -p ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.config/aj-snapshot
cp files/*.xml ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.config/aj-snapshot

cp files/jack.service ${ROOTFS_DIR}/usr/lib/systemd/system/

on_chroot << EOF
	adduser --no-create-home --system --group jack
	adduser jack audio --quiet
	adduser pi jack --quiet
	adduser root jack --quiet
	echo "JACK_PROMISCUOUS_SERVER=jack" >> /etc/environment
	# systemctl enable jack
EOF

