#!/bin/bash
#
# embedtool - executed after an image is generated & formatted
# 
# bootfs mountpoint: "$BUILDIMAGE_MOUNTPOINT"/"$BOOTFS_MOUNTPOINT"/
# rootfs mountpoint: "$BUILDIMAGE_MOUNTPOINT"/
#

local POSTGEN_DIR="$(dirname ${BASH_SOURCE[0]})"
local UBOOT_FILE="${POSTGEN_DIR}/boot/u-boot-sunxi-with-spl.bin"

dd if=/dev/zero of=$LOOPDEV bs=1k count=1023 seek=1 status=noxfer > /dev/null 2>&1 || {
    log_failure_msg "error on zero $LOOPDEV"
    return 1
}

dd if=$UBOOT_FILE of=$LOOPDEV bs=1024 seek=8 status=noxfer > /dev/null 2>&1 || {
    log_failure_msg "error on installing $UBOOT_FILE"
    return 1
}

return 0
