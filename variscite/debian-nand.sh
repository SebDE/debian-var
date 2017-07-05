#!/bin/bash
#
# Flash Debian into NAND for DART-MX6UL
#

#### global constants ####
readonly UBOOT_IMAGE='u-boot.img.nand'
readonly KERNEL_IMAGE='zImage'
KERNEL_DTB='imx7d-var-som-nand.dtb'
readonly ROOTFS_IMAGE='rootfs.ubi.img'
readonly IMAGES_PATH="/opt/images/Debian"
readonly UBI_SUB_PAGE_SIZE=2048
readonly UBI_VID_HDR_OFFSET=2048

usage()
{
	echo
	echo "This script installs Debian on the SOM's internal NAND flash"
	echo
	echo " Usage: `basename $0` OPTIONS"
	echo
	echo " OPTIONS:"
	echo " -m	install device tree with M4 support (imx7d-var-som-nand-m4.dtb, instead of the default imx7d-var-som-nand.dtb)"
	echo " -h	display this Help and exit"
	echo
}

while getopts mh OPTION;
do
	case $OPTION in
		m)
			KERNEL_DTB='imx7d-var-som-nand-m4.dtb'
			;;
		h)
			usage
			exit 0
			;;
	esac
done

echo "============================================"
echo " Variscite i.MX7 SOM"
echo " Installing Debian to NAND flash"
echo "============================================"
echo " Installing the following Device Tree file: "
echo " $KERNEL_DTB"
echo "============================================"

[[ $EUID -ne 0 ]] && {
	echo "This script must be run with super-user privileges" 
	exit 1
}

function install_bootloader()
{
	[ ! -f ${IMAGES_PATH}/$UBOOT_IMAGE ] && {
		echo "\"${IMAGES_PATH}/$UBOOT_IMAGE\"" does not exist! exit.
		exit 1
	};

	echo
	echo "Installing U-BOOT from \"${IMAGES_PATH}/$UBOOT_IMAGE\"..."
	flash_erase /dev/mtd0 0 0 2>/dev/null
	kobs-ng init -x ${IMAGES_PATH}/$UBOOT_IMAGE --search_exponent=1 -v > /dev/null

	# delete uboot env
	flash_erase /dev/mtd2 0 0 2>/dev/null
}

function install_kernel()
{
	[ ! -f ${IMAGES_PATH}/$KERNEL_IMAGE ] && {
		echo "\"${IMAGES_PATH}/$KERNEL_IMAGE\"" does not exist! exit.
		exit 1
	};

	echo
	echo "Installing Kernel"
	flash_erase /dev/mtd3 0 0 2>/dev/null
	nandwrite -p /dev/mtd3 ${IMAGES_PATH}/$KERNEL_IMAGE > /dev/null
	nandwrite -p /dev/mtd3 -s 0x7e0000 ${IMAGES_PATH}/$KERNEL_DTB > /dev/null
}

function install_rootfs()
{
	[ ! -f ${IMAGES_PATH}/$ROOTFS_IMAGE ] && {
		echo "\"${IMAGES_PATH}/$ROOTFS_IMAGE\"" does not exist! exit.
		exit 1
	};

	echo
	echo "Installing UBI rootfs"

	flash_erase /dev/mtd4 0 0 3>/dev/null
	ubiformat /dev/mtd4 -f ${IMAGES_PATH}/$ROOTFS_IMAGE -s $UBI_SUB_PAGE_SIZE -O $UBI_VID_HDR_OFFSET
}


#Creating 5 MTD partitions on "gpmi-nand":
#0x000000000000-0x000000200000 : "spl"
#0x000000200000-0x000000400000 : "uboot"
#0x000000400000-0x000000600000 : "uboot-env"
#0x000000600000-0x000000e00000 : "kernel"
#0x000000e00000-0x000040000000 : "rootfs"

echo "Flashing..."

install_bootloader

install_kernel

install_rootfs


read -p "Debian Flashed in NAND. Press any key to continue... " -n1
