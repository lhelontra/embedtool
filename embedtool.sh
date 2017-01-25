#!/bin/bash

# embedtool -*- shell-script -*-
#
#Copyright (c) 20016 Leonardo Lontra
#All rights reserved.
#
#Redistribution and use in source and binary forms, with or without
#modification, are permitted provided that the following conditions
#are met:
#1. Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
#2. Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
#3. Neither the name of the author nor the names of other contributors
#   may be used to endorse or promote products derived from this software
#   without specific prior written permission.
#
#THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
#IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE
#LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
#SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
#BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
#OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
#EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

declare -r QEMU_ARM_STATIC_BIN=$(whereis -b qemu-arm-static | awk '{ print $2 }')
declare -r RSYNC_BIN=$(whereis -b rsync | awk '{ print $2 }')
declare -r KPARTX_BIN=$(whereis -b kpartx | awk '{ print $2 }')
declare -r LOSETUP_BIN=$(whereis -b losetup | awk '{ print $2 }')

CONFIGPATH="./targets/"
RED='\033[0;31m'
BLUE='\033[1;36m'
NC='\033[0m'
LOCAL_SHAREDDIR=""
BUILDIMAGE_TARGET=""
SECTOR_SIZE=512
VERBOSE_MSG=""

function log_failure_msg() {
	echo -ne "[${RED}error${NC}] $@\n"
}

function error() {
	log_failure_msg "$@"
	exit 1
}

function log_app_msg() {
	[ ! -z $VERBOSE_MSG ] && echo -ne "[${BLUE}info${NC}] $@\n"
}

[[ $EUID -ne 0 ]] && error "This script must be run as root"
[ -z $QEMU_ARM_STATIC_BIN ] && error "Please, install qemu-user-static packages: apt-get install qemu qemu-user-static binfmt-support"
[ -z $RSYNC_BIN ] && error "Please, install rsync package: apt-get install rsync"
[ -z $KPARTX_BIN ] && error "Please, install kpartx package: apt-get install kpartx"

function usage() {
	echo -ne "Usage: $0 [-l|--targetlist] [-v|--verbose] [-d|--appendpath] [-t|--target <target>] [-s|--shared <shared diretory>] [options]\nOptions:\t
	-l, --targetlist                                                             lists the supported targets.
	-v, --verbose                                                                enable verbose.
	-ap, --appendpath                                                            Append target path.
	-t, --target <machine>                                                       load target config file. (default target: Null | default: config diretory: $CONFIGPATH)
	-m, --mount <imgfile|device> <mount_point_dir>                               mount source to mount point diretory.
	-u, --umount <mount_point_dir>                                               umount image mounted.
	-cp,--copy <device|image> <device destination|destination diretory>          copy data sorce to destination.
	-bimg, --buildimg <system diretory> <imagename>                              build image for target using diretory.
	-c, --chroot <imgfile|diretory> [\"cmd\"]                                    chroot in image or diretory and mount shared diretory and/or execute command using image enviroment. Use with in shared diretory.
	-s, --shared <shared diretory>                                               shared diretory for using with --chroot. Mount inside chroot image/diretory.
	\n"
	exit 1
}

function targetCheck() {
	[ -z $BUILDIMAGE_TARGET ] && { 
		log_failure_msg "Target machine not defined"
		usage
	}
}

function mountSharedDir() {
	local LOCALDIR="$1"
	local MOUNT_POINT="$2"
	log_app_msg "Mounting shared diretory at $CHROOT_SHAREDDIR"
	mkdir -p "$MOUNT_POINT"/"$CHROOT_SHAREDDIR" &>/dev/null
	mount -o bind "$LOCALDIR" "$MOUNT_POINT"/"$CHROOT_SHAREDDIR" || error "cant mount shared diretory"
}

function umountSharedDir() {
	umount "$1"/"$CHROOT_SHAREDDIR" &>/dev/null && log_app_msg "Umounting shared diretory: $1/$CHROOT_SHAREDDIR"
}

function _mount() {
	local SOURCE="$1"
	local MOUNT_POINT="$2"
	
	# mount block device
	if [ -b $SOURCE ]; then
		log_app_msg "Mounting ${SOURCE}2 at $MOUNT_POINT"
		mount "${SOURCE}2" "$MOUNT_POINT" || error "cant mount ${SOURCE}2"
		log_app_msg "Mounting ${SOURCE}1 at ${MOUNT_POINT}/${BOOTFS_MOUNTPOINT}"
		mkdir -p  "${MOUNT_POINT}"/"$BOOTFS_MOUNTPOINT"
		mount "${SOURCE}1" "${MOUNT_POINT}"/"$BOOTFS_MOUNTPOINT" || error "cant mount ${SOURCE}1"
	
	# mount image
	elif [ -f $SOURCE ]; then
		$LOSETUP_BIN -d $($LOSETUP_BIN --associated $SOURCE | awk '{ print $1 }' | cut -d: -f1) &>/dev/null
		FDISK_RESULT=$(/sbin/fdisk -lu $SOURCE)
		SECTOR_OFFSET=$(echo "$FDISK_RESULT" | awk '$7 == "Linux" || $6 == "Linux" { print $2 }')
		BYTE_OFFSET=$(($SECTOR_OFFSET * $SECTOR_SIZE))
		SECTOR_OFFSET_BOOT=$(echo "$FDISK_RESULT" | awk '$6 ~ /FAT|W95/ || $7 ~ /FAT|W95/ { print $2 }')
		log_app_msg "Mounting image / at $MOUNT_POINT/"
		log_app_msg "Sector offset $SECTOR_OFFSET - Byte offset $BYTE_OFFSET"
		mkdir -p "$MOUNT_POINT"/
		
		LOOPDEV=$($LOSETUP_BIN --find)
		$LOSETUP_BIN $LOOPDEV $SOURCE -o $BYTE_OFFSET
		mount -t auto $LOOPDEV $MOUNT_POINT/ || error "cant mount $MOUNT_POINT/" || error "cant mount $MOUNT_POINT/"
		
		if [ "$SECTOR_OFFSET_BOOT" != "" ]; then
            BYTE_OFFSET_BOOT=$(($SECTOR_OFFSET_BOOT * $SECTOR_SIZE))
            log_app_msg "Sector offset $SECTOR_OFFSET_BOOT - Byte offset $BYTE_OFFSET_BOOT" 
            log_app_msg "Mounting image ${BOOTFS_MOUNTPOINT} at $MOUNT_POINT/${BOOTFS_MOUNTPOINT}"
            mkdir -p "$MOUNT_POINT"/"$BOOTFS_MOUNTPOINT"
            
            LOOPDEV_BOOT=$($LOSETUP_BIN --find)
			$LOSETUP_BIN $LOOPDEV_BOOT $SOURCE -o $BYTE_OFFSET_BOOT
            mount -t auto $LOOPDEV_BOOT $MOUNT_POINT/${BOOTFS_MOUNTPOINT} || error "cant mount $MOUNT_POINT/${BOOTFS_MOUNTPOINT}"
		fi
		
	else
		error "mount only image or device"
	fi
}

function u_mount() {
	umount $1/${BOOTFS_MOUNTPOINT} &>/dev/null && log_app_msg "Umounting: $1/${BOOTFS_MOUNTPOINT}"
	umount $1/ &>/dev/null && log_app_msg "Umounting: $1"
}

function chrootArm() {
	[ -z $1 ] && usage
	local MOUNT_POINT="$1"
	local CMD="$2"
	# mount shared folder
	[ -d $LOCAL_SHAREDDIR ] && [ ! -z $LOCAL_SHAREDDIR ] && mountSharedDir $LOCAL_SHAREDDIR $MOUNT_POINT
	# prepare chroot
	log_app_msg "Disable $MOUNT_POINT/etc/ld.so.preload ..."
	sed -i -n 's/\(^.*\)/#\1/p' "$MOUNT_POINT"/etc/ld.so.preload &>/dev/null || log_failure_msg "cant read $MOUNT_POINT/etc/ld.so.preload"
	log_app_msg "copying qemu-arm-static .."
	# copy qemu-arm-static
	cp "$QEMU_ARM_STATIC_BIN" "$MOUNT_POINT"/"$QEMU_ARM_STATIC_BIN" &>/dev/null || {
		log_failure_msg "error on copy qemu-arm-static" 
		return 1
	}
	sync
	for mount_point in /dev /dev/pts /proc /sys ; do mount "$mount_point" -o bind "$MOUNT_POINT"/"$mount_point"; done
	# change to working dir and execute command and exit
	[ ! -z "$CMD" ] && { 
		log_app_msg "Launching command: $CMD"
		CMD="cd $CHROOT_SHAREDDIR ; $CMD ; exit"
	}
	chroot $MOUNT_POINT bin/bash --init-file <(echo 'cd;export PS1="\[\033[38;5;51m\]\u\[$(tput sgr0)\]\[\033[38;5;15m\]@\[$(tput sgr0)\]\[\033[38;5;9m\]QemuArm-$(uname -m)\[$(tput sgr0)\]\[\033[38;5;15m\] \[$(tput sgr0)\]\[\033[38;5;6m\]\w\[$(tput sgr0)\]\[\033[38;5;15m\] \\$: \[$(tput sgr0)\]"';echo "$CMD")
	log_app_msg "Reactivate $MOUNT_POINT/etc/ld.so.preload ..."
	sed -i -n 's/^#*\(.*\)/\1/p' "$MOUNT_POINT"/etc/ld.so.preload &>/dev/null || log_failure_msg "cant read $MOUNT_POINT/etc/ld.so.preload"
	log_app_msg "Removing qemu-arm-static"
	rm -f "$MOUNT_POINT"/"$QEMU_ARM_STATIC_BIN"
	sync
	for mount_point in /dev/pts /dev /proc /sys ; do umount "$MOUNT_POINT"/"$mount_point"; done
	umountSharedDir "$MOUNT_POINT"
}

function enterChroot() {
	[ -z $1 ] && usage
	local IMG_FILE="$1"
	local CMD="$2"
	local MOUNT_POINT="/tmp/.embedtool$RANDOM"
	mkdir -p $MOUNT_POINT || error "cant create temp diretory"
	# mount image partititons
	_mount "$IMG_FILE" "$MOUNT_POINT"
	# enable chroot arm
	chrootArm "$MOUNT_POINT" "$CMD"
	# umount image
	u_mount "$MOUNT_POINT"
	umountSharedDir "$MOUNT_POINT"
	rm -rf $MOUNT_POINT
}

function copy() {
	[ -z $1 ] || [ -z $2 ] && usage
	local SOURCE="$1"
	local DEST="$2"
	# image to device
	if [ -f $SOURCE ] && [ -b $DEST ]; then
		log_app_msg "recording $SOURCE to $DEST"
		dd if=$SOURCE of=$DEST status=none || log_failure_msg "cant record to $DEST device"
	# image to folder or device to folder
	else
		local SYS_MOUNTPOINT=${SOURCE}
		if [ -b $SOURCE ] || [ -f $SOURCE ]; then
			SYS_MOUNTPOINT="/tmp/.embedtool$RANDOM" 
			mkdir -p $SYS_MOUNTPOINT || error "cant create system diretory"
			_mount $SOURCE "$SYS_MOUNTPOINT"
		fi
		log_app_msg "copying $SOURCE to $DEST"
		$RSYNC_BIN --delete -avP --stats --human-readable "$SYS_MOUNTPOINT"/* "${DEST}" 1>/dev/null || log_failure_msg "Cant copy files $SYS_MOUNTPOINT to $DEST"
	fi
	sync
	# if source is block or image, remove temporary diretory
	if [ -b $SOURCE ] || [ -f $SOURCE ]; then
		u_mount $SYS_MOUNTPOINT
		rm -rf $SYS_MOUNTPOINT
	fi
	log_app_msg "done"
}

function buildImg() {
	local TARGET="$1"
	local IMAGE="$2"
	[ -z $IMAGE ] || [ -z $TARGET ] && error "invalid arguments"
	[ ! -d $TARGET ] && error "Target is not a directory"
	[ -f $IMAGE ] && {
		echo -n "File $IMAGE exists. You want to overwrite (y/n)? "
		read answer
		echo "$answer" | grep -iq "^n" && exit 0 
	}
	log_app_msg "Target image: $IMAGE | Target diretory: $TARGET"
	# size without boot folder
	local SYSTEM_PART_SIZE_MB=$(du --total --exclude="${TARGET}/${BOOTFS_MOUNTPOINT}/*" -m ${TARGET} | tail -n 1 | awk '{ print $1 }')
	# rootfs + extra size
	SYSTEM_PART_SIZE_MB=$(($SYSTEM_PART_SIZE_MB+$BUILDIMAGE_SYSTEM_EXTRA_SIZE_MB))
	# rootfs + reserved blocks
	SYSTEM_PART_SIZE_MB=$(awk "BEGIN { printf \"%.0f\n\", $SYSTEM_PART_SIZE_MB * (1 + ($BUILDIMAGE_RESERVED_BLOCKS_PERCENT / 100)) }")
	# convert bootfs size mb to bytes sector
	local BOOTFS_PART_SIZE_BYTES_SECTOR=$(awk "BEGIN { printf \"%.0f\n\", (($BUILDIMAGE_BOOTFS_PART_SIZE_MB * 1024) * 1024) / $SECTOR_SIZE }")
	# begining sector
	local START_SECTOR=$(($BOOTFS_PART_SIZE_BYTES_SECTOR+$BUILDIMAGE_BOOTFS_START_SECTOR))
	# calculate total size bootfs + rootfs
	local IMG_SIZE_BYTES=$(awk "BEGIN { printf \"%.0f\n\", ((($SYSTEM_PART_SIZE_MB + $BUILDIMAGE_BOOTFS_PART_SIZE_MB) * 1024) * 1024) / $SECTOR_SIZE }")
	log_app_msg "Creating $IMAGE with boot size: ${BUILDIMAGE_BOOTFS_PART_SIZE_MB}MB | root size: ${SYSTEM_PART_SIZE_MB}MB | Reserved blocks: ${BUILDIMAGE_RESERVED_BLOCKS_PERCENT}%"
	# create image
	dd if=/dev/zero of=$IMAGE count=$IMG_SIZE_BYTES bs=$SECTOR_SIZE status=none || error "Error on create image"
	# erase first 512 bytes mbr / lb1
	dd if=/dev/zero of=$IMAGE bs=$SECTOR_SIZE count=1 conv=notrunc status=none || error "Error on create image"
	sync
# 	fdisk ${IMAGE} << EOF
# 	n
# 	p
# 	1
# 	$BUILDIMAGE_BOOTFS_START_SECTOR
# 	$(($START_SECTOR-1))
# 	t
# 	$BUILDIMAGE_BOOTFS_TYPE_ID
# 	n
# 	p
# 	2
# 	$START_SECTOR
# 
# 	w
# 	EOF
	log_app_msg "Partitiong image.."
	echo -ne "n\np\n1\n$BUILDIMAGE_BOOTFS_START_SECTOR\n$(($START_SECTOR-1))\nt\n$BUILDIMAGE_BOOTFS_TYPE_ID\nn\np\n2\n$START_SECTOR\n\nw\n" | fdisk ${IMAGE} 1>/dev/null
	[ $? != 0 ] && error "Error in partition image" 
	log_app_msg "Mapping devices..."
	sync
	# mapping devices
	local KPARTX_VERBOSE="$($KPARTX_BIN -vasl "$IMAGE")"
	local MAPPED_DEVS=($(echo "$KPARTX_VERBOSE" | awk '{ print $1 }'))
	local LOOPDEV="$(echo "$KPARTX_VERBOSE" | head -n1 | awk '{ print $5 }')"
	
	local BOOTFS="/dev/${MAPPED_DEVS[0]}"
	local ROOTFS="/dev/${MAPPED_DEVS[1]}"
	if [ -b /dev/mapper/${MAPPED_DEVS[0]} ]; then
        local BOOTFS="/dev/mapper/${MAPPED_DEVS[0]}"
	fi
	
	if [ -b /dev/mapper/${MAPPED_DEVS[1]} ]; then
        local ROOTFS="/dev/mapper/${MAPPED_DEVS[1]}"
	fi
	
	# partition table changes, force re-read the partition table.
	partprobe $LOOPDEV
	# format bootfs
	log_app_msg "Formating ${BOOTFS}"
	mkfs -t $BUILDIMAGE_BOOTFS_TYPE $BUILDIMAGE_BOOTFS_MKFS_ARGS "${BOOTFS}" &>/dev/null || { 
		$LOSETUP_BIN -d $LOOPDEV
		error "Cant format ${BOOTFS_MOUNTPOINT}"
	}
	# format rootfs
	log_app_msg "Formating ${ROOTFS}"
	mkfs -t $BUILDIMAGE_ROOTFS_TYPE $BUILDIMAGE_ROOTFS_MKFS_ARGS "${ROOTFS}" &>/dev/null || { 
		$LOSETUP_BIN -d $LOOPDEV
		error "Cant format / rootfs"
	}
	
	# NOTE: if defined, overwrite mke2fs default flags
	[ ! -z "$BUILDIMAGE_ROOTFS_FLAGS" ] && {
		log_app_msg "Overwrite mk2fs flags"
		mke2fs -F -O $BUILDIMAGE_ROOTFS_FLAGS ${ROOTFS} &>/dev/null || { 
			$LOSETUP_BIN -d $LOOPDEV
			error "Cant overwrite mk2fs flags"
		}
	}
	
	# get uuid of bootfs & rootfs for use in scripts
	local ROOTFS_UUID="$(blkid -s UUID -o value $ROOTFS)"
	local BOOTFS_UUID="$(blkid -s UUID -o value $BOOTFS)"
	# execute script to write bootloader (if necessary)
	if [ -f "$CONFIGPATH"/"$BUILDIMAGE_TARGET"/"$BUILDIMAGE_AFTERGEN" ]; then
		log_app_msg "executing $BUILDIMAGE_AFTERGEN"
		source "$CONFIGPATH"/"$BUILDIMAGE_TARGET"/"$BUILDIMAGE_AFTERGEN" || { 
			$LOSETUP_BIN -d $LOOPDEV
			error "Cant run $BUILDIMAGE_AFTERGEN"
		}
	fi 
	# create temp dir
	local BUILDIMAGE_MOUNTPOINT="/tmp/.embedtool$RANDOM"
	log_app_msg "Creating ${BUILDIMAGE_MOUNTPOINT}.."
	mkdir -p "$BUILDIMAGE_MOUNTPOINT" || error "Cant create $BUILDIMAGE_MOUNTPOINT"
	# mount loop devices
	log_app_msg "Mounting ${ROOTFS} at $BUILDIMAGE_MOUNTPOINT"
	mount "${ROOTFS}" "$BUILDIMAGE_MOUNTPOINT" || error "Cant mount ${ROOTFS} at $BUILDIMAGE_MOUNTPOINT"
	mkdir -p "$BUILDIMAGE_MOUNTPOINT"/"${BOOTFS_MOUNTPOINT}"
	log_app_msg "Mounting ${BOOTFS} at $BUILDIMAGE_MOUNTPOINT/${BOOTFS_MOUNTPOINT}"
	mount "${BOOTFS}" "$BUILDIMAGE_MOUNTPOINT"/"${BOOTFS_MOUNTPOINT}" || error "Cant mount ${BOOTFS} at $BUILDIMAGE_MOUNTPOINT"
	# copy data
	log_app_msg "Copying ${TARGET} to $BUILDIMAGE_MOUNTPOINT"
	#-rltvz
	rsync --delete -avP --stats --human-readable "$TARGET"/* "$BUILDIMAGE_MOUNTPOINT" 1>/dev/null || log_failure_msg "Cant copy files ${TARGET} to $BUILDIMAGE_MOUNTPOINT"
	sync
	# execute after copying data
	if [ -f "$CONFIGPATH"/"$BUILDIMAGE_TARGET"/"$BUILDIMAGE_AFTERCOPYDATA" ]; then
		log_app_msg "executing $BUILDIMAGE_AFTERCOPYDATA"
		source "$CONFIGPATH"/"$BUILDIMAGE_TARGET"/"$BUILDIMAGE_AFTERCOPYDATA" || { 
			$LOSETUP_BIN -d $LOOPDEV
			error "Cant run $BUILDIMAGE_AFTERCOPYDATA"
		}
	fi 
	# umount temp dir
	log_app_msg "Umounting ${BUILDIMAGE_MOUNTPOINT}.."
	umount "$BUILDIMAGE_MOUNTPOINT"/"${BOOTFS_MOUNTPOINT}"
	umount "$BUILDIMAGE_MOUNTPOINT"
	sync
	# delete loop device
	log_app_msg "Deleting loop devices.."
	$LOSETUP_BIN -d $LOOPDEV
	# remove temp diretory
	rm -rf "$BUILDIMAGE_MOUNTPOINT"
	log_app_msg "$IMAGE generated"
	exit 0
}

while [ "$1" != "" ]; do
	case $1 in
		-l|--targetlist)
			log_app_msg "lists the supported targets:"
			ls "${CONFIGPATH}" 2>/dev/null || error "targets list not found"
		;;
		-v|--verbose)
			VERBOSE_MSG="yes"
		;;
		-ap|--appendpath)
			shift
			log_app_msg "Append target path: $1"
			CONFIGPATH="$1 $CONFIGPATH"
		;;
		-t|--target)
			shift
			log_app_msg "Loading target config: $1"
			BUILDIMAGE_TARGET="$1"
			CONFIGPATH=$(dirname $(whereis -M $CONFIGPATH -f $BUILDIMAGE_TARGET | awk '{ print $2 }') 2>/dev/null)
			source "$CONFIGPATH/$BUILDIMAGE_TARGET/config" &>/dev/null || error "Failed to load config"
		;;
		-s|--shared)
			shift
			LOCAL_SHAREDDIR="$1"
		;;
		-c|--chroot)
			shift
			targetCheck
			if [ -d $1 ]; then
				chrootArm "$1" "$2" "$3"
			else
				enterChroot "$1" "$2" "$3"
			fi
		;;
		-m|--mount)
			shift
			targetCheck
			_mount "$1" "$2"
		;;
		-u|--umount)
			shift
			targetCheck
			u_mount "$1"
		;;
		-cp|--copy)
			shift
			targetCheck
			copy "$1" "$2"
		;;
		-bimg|--buildimg)
			shift
			targetCheck
			buildImg "$1" "$2"
		;;
		-h|--help)
			usage
		;;
	esac
	shift
done
