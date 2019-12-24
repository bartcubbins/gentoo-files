#!/bin/bash

#
# List of functions in order of execution
#
# main()
# help()
# chroot_handler()

# connection_test()
# prepare_partitions()
# pre_mount_fs()
# stage3_download()
# stage3_remove()
# mount_fs()
# chroot_profile_set()
# chroot_set_use()
# chroot_common_prepare()
# chroot_kde_install()
# chroot_emerge_packages()
# chroot_sudoers_patch()
# chroot_kernel_clone()
# chroot_kernel_build()
# chroot_user_create()
#

# Variables block
MIRROR=http://distfiles.gentoo.org
STEPS="connection_test,prepare_partitions,pre_mount_fs,network_conf,connection_test,stage3_download,stage3_remove,mount_fs,chroot_profile_set,chroot_set_use,chroot_common_prepare,chroot_kde_install,chroot_emerge_packages,chroot_sudoers_patch,chroot_kernel_clone,chroot_kernel_build,chroot_user_create"
CHROOT=false
TIMEZONE="Europe/Kiev"
DESTINATION=/mnt/gentoo
KERNEL_SOURCE=https://github.com/bartcubbins/linux.git
KERNEL_DEFCONFIG=defconfig
BOOT_PARTITION=/dev/nvme0n1p5
SYSTEM_PARTITION=/dev/nvme0n1p6
HOME_PARTITION=/dev/sda1
#SWAP_PARTITION=
SYSTEM_FS=f2fs
BOOT_FS=fat
HOME_FS=ext4

# Main function
function main() {
	#iterate through each step
	CURRENT_STEP=$(echo -n "$STEPS" | sed -r -e 's/([^,]+),?.*?/\1/')
	REMAINING_STEPS=$(echo -n "$STEPS" | sed -r -e 's/[^,]+,?(.*?)/\1/')
	while [ "$CURRENT_STEP" != "" ]; do
		case "$CURRENT_STEP" in
			"connection_test")		connection_test;;
			"prepare_partitions")		prepare_partitions;;
			"pre_mount_fs")			pre_mount_fs;;
			"stage3_download")		stage3_download;;
			"stage3_remove")		stage3_remove;;
			"mount_fs")			mount_fs;;
			"network_conf")			network_conf;;
			"connection_test")		chroot_handler;;
			"chroot_profile_set")		chroot_handler;;
			"chroot_set_use")		chroot_handler;;
			"chroot_common_prepare")	chroot_handler;;
			"chroot_kde_install")		chroot_handler;;
			"chroot_emerge_packages")	chroot_handler;;
			"chroot_sudoers_patch")		chroot_handler;;
			"chroot_kernel_clone")		chroot_handler;;
			"chroot_kernel_build")		chroot_handler;;
			"chroot_user_create")		chroot_handler;;
			*)
				echo "Error: Unknown step: \"$CURRENT_STEP\""
				break
				;;
		esac
		CURRENT_STEP=$(echo -n "$REMAINING_STEPS" | sed -r -e 's/([^,]+),?.*?/\1/')
		REMAINING_STEPS=$(echo -n "$REMAINING_STEPS" | sed -r -e 's/[^,]+,?(.*?)/\1/')
	done
}

function help() {
	echo "Usage: $0 [option...] {param}" >&2
	echo
	echo "   -h, --help           Print a help message and exit."
	echo

	exit 1
}

function network_conf() {
	cp --dereference /etc/resolv.conf "$DESTINATION/etc/"
}

function connection_test() {
	echo "Checking internet connection..."

	ping -q -c3 google.com &> /dev/null
	if [ $? -eq 0 ]; then
		echo "Сonnection successful."
	else
		echo "No internet connection. Exit."
		exit 1
	fi
	
}

# Download the latest stage3 tarball
function stage3_download() {
	echo "Downloading stage 3 archive..."

	# Get latest stage3 name
	latest_stage_name=$(wget --quiet "$MIRROR/releases/amd64/autobuilds/latest-stage3-amd64.txt"  -O- | tail -n 1 | cut -d " " -f 1)

	# Download stage3
	wget -q --show-progress "$MIRROR/releases/amd64/autobuilds/$latest_stage_name" -O "$DESTINATION"
	wget -q --show-progress "$MIRROR/releases/amd64/autobuilds/$latest_stage_name.DIGESTS.asc" -O "$DESTINATION"

	# Verify downloaded stage3
	# Gentoo Linux Release Engineering (Automated Weekly Release Key)
	# Created: 2009-08-25
	# Expiry:  2021-01-01
	gpg --keyserver hkps://keys.gentoo.org --recv-keys 13EBBDBEDE7A12775DFDB1BABB572E0E2D182910 &> /dev/null
	gpg --verify "$DESTINATION/stage3-"*".tar.xz.DIGESTS.asc" &> /dev/null
	grep $(sha512sum "$DESTINATION/stage3-"*".tar.xz") "$DESTINATION/stage3-"*".tar.xz.DIGESTS.asc" &> /dev/null
	if [ $? -ne 0 ]; then
		echo "Failed! Remove downloaded stage3 and exit."
		stage3_remove
		exit 1
	fi

	# Extract downloaded stage3
	tar xpf "$DESTINATION/stage3-"*".tar.xz" --xattrs-include='*.*' --numeric-owner
	# We don't need stage3 archive anymore. Remove it
	stage3_remove

	echo "Stage3 downloaded, verified and successfully extraced."
}

function stage3_remove() {
	rm "$DESTINATION"/stage3-*.tar.xz*
}

function prepare_partitions() {
	echo "Format partitions:"
	echo ""

	if [ "$SYSTEM_PARTITION" != "" ] && [ "$SYSTEM_FS" != "" ]; then
		read -p "Format system partition ("$SYSTEM_PARTITION") using "$SYSTEM_FS" filesystem? [Y/n]: "
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			mkfs."$SYSTEM_FS" "$SYSTEM_PARTITION"
		else
			echo "Formatting canceled."
		fi
	fi
	if [ "$BOOT_PARTITION" != "" ] && [ "$BOOT_FS" != "" ]; then
		read -p "Format boot partition ("$BOOT_PARTITION") using "$BOOT_FS" filesystem? [Y/n]: "
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			mkfs."$BOOT_FS" "$BOOT_PARTITION"
		else
			echo "Formatting canceled."
		fi
	fi
	if [ "$SWAP_PARTITION" != "" ]; then
		mkswap "SWAP_PARTITION"
	fi
	if [ "$HOME_PARTITION" != "" ] && [ "$HOME_FS" != "" ]; then
		read -p "Format home partition ("$HOME_PARTITION") using "$HOME_FS" filesystem? [Y/n]: "
		if [[ $REPLY =~ ^[Yy]$ ]]; then
			mkfs."$HOME_FS" "$HOME_PARTITION"
		else
			echo "Formatting canceled."
		fi
	fi
}

function pre_mount_fs() {
	mount "$SYSTEM_PARTITION" "$DESTINATION"
	mkdir -p "$DESTINATION/boot"
	mount "$BOOT_PARTITION" "$DESTINATION/boot"
	if [ "$SWAP_PARTITION" != "" ]; then
		swapon "$SWAP_PARTITION"
	fi
}

function mount_fs() {
	# Mounting the necessary filesystems
	mount --types proc /proc "$DESTINATION/proc"
	mount --rbind /sys "$DESTINATION/sys"
	mount --make-rslave "$DESTINATION/sys"
	mount --rbind /dev "$DESTINATION/dev"
	mount --make-rslave "$DESTINATION/dev"

	echo "All the necessary filesystems are mounted successfully"
}

function chroot_handler() {
	if $CHROOT; then
		"$CURRENT_STEP"
		rm /tmp/gentoo_install.sh
	else
		cp -f "$0" "$DESTINATION"/tmp
		chroot "$DESTINATION" /tmp/gentoo_install.sh --chroot --step "$CURRENT_STEP"
	fi
}

function chroot_set_use() {
	# make.conf path
	local CONF_FILE=etc/portage/make.conf

	echo "# These settings were set by the catalyst build script that automatically" > $CONF_FILE
	echo "# built this stage." >> $CONF_FILE
	echo "# Please consult /usr/share/portage/config/make.conf.example for a more" >> $CONF_FILE
	echo "# detailed example." >> $CONF_FILE
	echo "COMMON_FLAGS=\"-march=skylake -O2 -pipe\"" >> $CONF_FILE
	echo "CFLAGS=\"\${COMMON_FLAGS}\"" >> $CONF_FILE
	echo "CXXFLAGS=\"\${COMMON_FLAGS}\"" >> $CONF_FILE
	echo "FCFLAGS=\"\${COMMON_FLAGS}\"" >> $CONF_FILE
	echo "FFLAGS=\"\${COMMON_FLAGS}\"" >> $CONF_FILE

	echo "" >> $CONF_FILE

	echo "# NOTE: This stage was built with the bindist Use flag enabled" >> $CONF_FILE
	echo "PORTDIR=\"/var/db/repos/gentoo\"" >> $CONF_FILE
	echo "DISTDIR=\"/var/cache/distfiles\"" >> $CONF_FILE
	echo "PKGDIR=\"/var/cache/binpkgs\"" >> $CONF_FILE

	echo "" >> $CONF_FILE

	echo "# This sets the language of build output to English." >> $CONF_FILE
	echo "# Please keep this setting intact when reporting bugs." >> $CONF_FILE
	echo "LC_MESSAGES=C" >> $CONF_FILE

	echo "" >> $CONF_FILE

	echo "CPU_FLAGS_X86=\"aes avx avx2 f16c fma3 mmx mmxext pclmul popcnt sse sse2 sse3 sse4_1 sse4_2 ssse3\"" >> $CONF_FILE

	echo "" >> $CONF_FILE

	echo "MAKEOPTS=\"-j12\"" >> $CONF_FILE

	echo "" >> $CONF_FILE

	echo "# TODO: Add mirrors" >> $CONF_FILE
	echo "#GENTOO_MIRRORS=\"\"" >> $CONF_FILE
	echo "VIDEO_CARDS=\"intel i965 nvidia\"" >> $CONF_FILE
	echo "USE=\"-gnome\"" >> $CONF_FILE
}

function chroot_common_prepare() {
	emerge-webrsync --quiet
	emerge --sync --quiet
	
	# https://bugs.gentoo.org/434090
	# https://bugs.gentoo.org/477240
	# https://bugs.gentoo.org/477498
	ln -sf /proc/self/mounts /etc/mtab

	# Timezone configuration
	echo "$TIMEZONE" > /etc/timezone
	emerge --config sys-libs/timezone-data

	# Locale configuration
	echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
	locale-gen
	eselect locale set en_US.utf8
	env-update
	source /etc/profile

	# Update the @world set
	emerge --quiet --update --deep --newuse @world
}

function chroot_profile_set() {
	# Select KDE Plasma as DE
	eselect profile set default/linux/amd64/17.1/desktop/plasma/systemd
}

function chroot_kde_install() {
	emerge --quiet kde-plasma/plasma-meta
}

function chroot_emerge_packages() {
	# It's possible that this function has already
	# been executed and ended with an error, let's
	# start emerge --resume first
	emerge --resume

	emerge --quiet app-admin/sudo \
		dev-vcs/git \
		net-wireless/wireless-regdb \
		sys-firmware/intel-microcode \
		sys-kernel/linux-firmware
}

function chroot_sudoers_patch() {
	# DANGEROUS! Allow members of group wheel to
	# execute any command
	sed --in-place 's/^#\s*\(%wheel\s\+ALL=(ALL)\s\+ALL\)/\1/' /etc/sudoers
}

function chroot_kernel_clone() {
	git clone --depth=1 --branch=master "$KERNEL_SOURCE" /usr/src/linux-mainline
}

function chroot_kernel_build() {
	eselect kernel set linux-mainline

	# Previous command creates this symlink
	cd /usr/src/linux

	make "$KERNEL_DEFCONFIG"
	make -j12

	# Clean boot folder if it's not empty
	rm -rf /boot/*
	make install
	make modules_install

	# Go back to root
	cd /
}

function chroot_user_create() {
	read -p "Do you want to set a password for the root user? [Y/n]: "
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		passwd root
	fi

	read -p "Do you want to create a new user? [Y/n]: "
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		while [ -z "$USER_NAME" ]; do
			read -p "Enter new user name: " USER_NAME
			if [ -z "$USER_NAME" ]; then
				echo "User name cannot be empty. Please try again."
			else
				# Conver uppercase user name to lowercase
				USER_NAME=${USER_NAME,,}
				useradd -m -G users,wheel,audio,portage,usb,video -s /bin/bash "$USER_NAME"
				passwd "$USER_NAME"
			fi
		done
	fi
}

# Command line parser
while [ $# -ne 0 ]; do
	case "$1" in
		"--chroot")
			CHROOT=true
			shift
			;;
		"-h" | "--help")
			help
			exit
			;;
		"-p" | "--step")
			STEPS="$2"
			shift 2
			;;
		"-m" | "--mirror")
			MIRROR="$2"
			shift 2
			;;
		*)
			echo "Error: unrecognized argument \"$1\""
			exit 1
			break;;
	esac
done

# Execute main function
main
