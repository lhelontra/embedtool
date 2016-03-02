#!/bin/bash
#
# embedtool - executed after an image is generated & formatted after copying script example
#
# based on http://odroid.com/dokuwiki/doku.php?id=en:c1_ubuntu_minimal
# bootfs mountpoint: "$BUILDIMAGE_MOUNTPOINT"/"$BOOTFS_MOUNTPOINT"/
# rootfs mountpoint: "$BUILDIMAGE_MOUNTPOINT"/
#

local POSTGEN_DIR="$(dirname ${BASH_SOURCE[0]})"

cat << EOF > "$BUILDIMAGE_MOUNTPOINT"/etc/fstab
# UNCONFIGURED FSTAB FOR BASE SYSTEM

LABEL=rootfs          /       ext4    errors=remount-ro,noatime,nodiratime            0 1
LABEL=boot            /media/boot     vfat    defaults,rw,owner,flush,umask=000       0 0
tmpfs                 /tmp    tmpfs   nodev,nosuid,mode=1777                          0 0
EOF

# enable serial console
cat << EOF > "$BUILDIMAGE_MOUNTPOINT"/etc/init/ttyS0.conf
start on stopped rc or RUNLEVEL=[12345]
stop on runlevel [!12345]
respawn
exec /sbin/getty -L 115200 ttyS0 vt102
EOF

return 0
