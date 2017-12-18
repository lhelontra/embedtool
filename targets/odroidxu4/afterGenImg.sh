#!/bin/bash
#
# embedtool - executed after an image is generated & formatted
# 
# bootfs mountpoint: "$BUILDIMAGE_MOUNTPOINT"/"$BOOTFS_MOUNTPOINT"/
# rootfs mountpoint: "$BUILDIMAGE_MOUNTPOINT"/
# uboot of hardkernel v2017.05

local POSTGEN_DIR="$(dirname ${BASH_SOURCE[0]})"

bl1="${POSTGEN_DIR}/boot/bl1.bin.hardkernel"
bl2="${POSTGEN_DIR}/boot/bl2.bin.hardkernel"
tzsw="${POSTGEN_DIR}/boot/tzsw.bin.hardkernel"
uboot_bin="${POSTGEN_DIR}/boot/u-boot.bin.hardkernel"

signed_bl1_position=1
bl2_position=31
uboot_position=63
tzsw_position=1503
env_position=2015

log_app_msg "Installing $bl1"
dd iflag=dsync oflag=dsync if=$bl1 of=$LOOPDEV seek=$signed_bl1_position status=none || {
	log_failure_msg "error on installing $bl1"
	return 1
}

log_app_msg "Installing $bl2"
dd iflag=dsync oflag=dsync if=$bl2 of=$LOOPDEV seek=$bl2_position status=none || {
	log_failure_msg "error on installing $bl2"
	return 1
}

log_app_msg "Installing $uboot_bin"
dd iflag=dsync oflag=dsync if=$uboot_bin of=$LOOPDEV seek=$uboot_position status=none || {
	log_failure_msg "error on installing $uboot_bin"
	return 1
}

log_app_msg "Installing $tzsw"
dd iflag=dsync oflag=dsync if=$tzsw of=$LOOPDEV seek=$tzsw_position status=none || {
	log_failure_msg "error on installing $tzsw"
	return 1
}

dd iflag=dsync oflag=dsync if=/dev/zero of=$LOOPDEV seek=$env_position count=32 bs=512 status=none

return 0
