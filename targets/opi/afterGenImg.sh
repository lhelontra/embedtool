#!/bin/bash
#
# embedtool - executed after an image is generated & formatted
# 
# bootfs mountpoint: "$BUILDIMAGE_MOUNTPOINT"/"$BOOTFS_MOUNTPOINT"/
# rootfs mountpoint: "$BUILDIMAGE_MOUNTPOINT"/
#

local POSTGEN_DIR="$(dirname ${BASH_SOURCE[0]})"
local BOOT0_OPI="${POSTGEN_DIR}/boot/boot0_OPI.fex"
local UBOOT0_OPI="${POSTGEN_DIR}/boot/u-boot_OPI.fex"

log_app_msg "Installing $BOOT0_OPI"
dd if=$BOOT0_OPI of=$LOOPDEV bs=1k seek=8 conv=notrunc status=none || {
	log_failure_msg "error on installing $BOOT0_OPI"
	return 1
}

log_app_msg "Installing $UBOOT0_OPI"
dd if=$UBOOT0_OPI of=$LOOPDEV bs=1k seek=16400 conv=notrunc status=none || {
	log_failure_msg "error on installing $UBOOT0_OPI"
	return 1
}

return 0