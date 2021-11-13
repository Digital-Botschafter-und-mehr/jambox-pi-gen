# custom-built kernels are best installed from repo ( in file 00-packages )
# in order to actually boot from them, files must be copied to /boot,
# and /boot/config.txt must have info added to it.

install_kernel_from_deb () {

KERN=$1
shift
mkdir -p ${ROOTFS_DIR}/boot/$KERN/overlays/
cp -d ${ROOTFS_DIR}/usr/lib/linux-image-$KERN/overlays/* ${ROOTFS_DIR}/boot/$KERN/overlays/
cp -d ${ROOTFS_DIR}/usr/lib/linux-image-$KERN/* ${ROOTFS_DIR}/boot/$KERN/
[[ -d ${ROOTFS_DIR}/usr/lib/linux-image-$KERN/broadcom ]] && cp -d ${ROOTFS_DIR}/usr/lib/linux-image-$KERN/broadcom/* ${ROOTFS_DIR}/boot/$KERN/
touch ${ROOTFS_DIR}/boot/$KERN/overlays/README
mv ${ROOTFS_DIR}/boot/vmlinuz-$KERN ${ROOTFS_DIR}/boot/$KERN/
mv ${ROOTFS_DIR}/boot/System.map-$KERN ${ROOTFS_DIR}/boot/$KERN/
cp ${ROOTFS_DIR}/boot/config-$KERN ${ROOTFS_DIR}/boot/$KERN/

# append kernel options to /boot/config.txt
while (( "$#" )); do 
cat >> ${ROOTFS_DIR}/boot/config.txt << EOF

[$1]
kernel=vmlinuz-$KERN
# initramfs initrd.img-$KERN
os_prefix=$KERN/
overlay_prefix=overlays/$(if [[ "$KERN" =~ 'v8' ]]; then echo -e "\narm_64bit=1"; fi)
[all]
EOF
shift
done
}

#install_kernel_from_deb "5.10.35-rt39-v7l+" "none"
install_kernel_from_deb "5.10.44-v8+" "none"
install_kernel_from_deb "5.10.46-v7l+" "none"
install_kernel_from_deb "5.10.52-rt47-v7l+" "none"
install_kernel_from_deb "5.10.52-v7l+" "all"


# give audio group ability to raise priority with "nice"
sed -i "s/.*audio.*nice.*$/@audio   -  nice      -19/g" ${ROOTFS_DIR}/etc/security/limits.d/audio.conf

# copy modprobe config needed to support Focusrite Scarlett gen3 interfaces
cp files/scarlett-gen3.conf ${ROOTFS_DIR}/etc/modprobe.d/

