# install rt-tests
git clone --depth 1 --branch stable/v1.0 https://git.kernel.org/pub/scm/utils/rt-tests/rt-tests.git ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/rt-tests/

# Copy script for latency test
cp files/gen-latency-plot.sh ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/rt-tests/
chmod +x ${ROOTFS_DIR}/home/${FIRST_USER_NAME}/rt-tests/gen-latency-plot.sh
