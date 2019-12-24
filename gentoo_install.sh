#!/bin/bash

# Variables block
MIRROR=http://distfiles.gentoo.org
STEPS="locale,timezone,set_use"
CHROOT=false
TIMEZONE="Europe/Kiev"
DESTINATION=/mnt/gentoo
#BOOT_PARTITION=/dev/
#SYSTEM_PARTITION=/dev/
#SWAP_PARTITION=
#SYSTEM_FS=f2fs
#BOOT_FS=fat

# Main function
function main() {
	#iterate through each step
	CURRENT_STEP=$(echo -n "$STEPS" | sed -r -e 's/([^,]+),?.*?/\1/')
	REMAINING_STEPS=$(echo -n "$STEPS" | sed -r -e 's/[^,]+,?(.*?)/\1/')
	while [ "$CURRENT_STEP" != "" ]; do
		case "$CURRENT_STEP" in
			"locale" \
			| "timezone" \
			| "set_use")      chroot_handler;;
			"mount_fs")	  mount_fs;;
			*)
				echo "error: unknown step: \"$CURRENT_STEP\""
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
	wget -q --show-progress "$MIRROR/releases/amd64/autobuilds/$latest_stage_name"
	wget -q --show-progress "$MIRROR/releases/amd64/autobuilds/$latest_stage_name.DIGESTS.asc"

	# Verify downloaded stage3
	# Gentoo Linux Release Engineering (Automated Weekly Release Key)
	# Created: 2009-08-25
	# Expiry:  2021-01-01
	gpg --keyserver hkps://keys.gentoo.org --recv-keys 13EBBDBEDE7A12775DFDB1BABB572E0E2D182910 &> /dev/null
	gpg --verify "stage3-"*".tar.xz.DIGESTS.asc" &> /dev/null
	grep $(sha512sum "stage3-"*".tar.xz") "stage3-"*".tar.xz.DIGESTS.asc" &> /dev/null
	if [ $? -ne 0 ]; then
		echo "Failed! Remove downloaded stage3 and exit."
		stage3_remove
		exit 1
	fi

	# Extract downloaded stage3
	tar xpf "stage3-"*".tar.xz" --xattrs-include='*.*' --numeric-owner
	# We don't need stage3 archive anymore. Remove it
	stage3_remove

	echo "Stage3 downloaded, verified and successfully extraced."
}

function stage3_remove() {
	rm stage3-*.tar.xz*
}

function prepare_partitions () {
	echo "Format partitions"

	if [ "$SYSTEM_PARTITION" != "" ] && [ "$SYSTEM_FS" != "" ]; then
		mkfs."$SYSTEM_FS" "$SYSTEM_PARTITION"
	fi
	if [ "$BOOT_PARTITION" != "" ] && [ "$BOOT_FS" != "" ]; then
		mkfs."$BOOT_FS" "$BOOT_PARTITION"
	fi
	if [ "$SWAP_PARTITION" != "" ]; then
		mkswap "SWAP_PARTITION"
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
		chroot_"$CURRENT_STEP"
		rm /tmp/gentoo_install.sh
	else
		cp -f "$0" "$DESTINATION"/tmp
		chroot "$DESTINATION" /tmp/gentoo_install.sh --chroot --step "$CURRENT_STEP"
	fi
}

function chroot_set_use() {
	# make.conf file encrypted with base64
	echo "IyBUaGVzZSBzZXR0aW5ncyB3ZXJlIHNldCBieSB0aGUgY2F0YWx5c3QgYnVpbGQgc2NyaXB0IHRo
YXQgYXV0b21hdGljYWxseQojIGJ1aWx0IHRoaXMgc3RhZ2UuCiMgUGxlYXNlIGNvbnN1bHQgL3Vz
ci9zaGFyZS9wb3J0YWdlL2NvbmZpZy9tYWtlLmNvbmYuZXhhbXBsZSBmb3IgYSBtb3JlCiMgZGV0
YWlsZWQgZXhhbXBsZS4KQ09NTU9OX0ZMQUdTPSItbWFyY2g9c2t5bGFrZSAtTzIgLXBpcGUiCkNG
TEFHUz0iJHtDT01NT05fRkxBR1N9IgpDWFhGTEFHUz0iJHtDT01NT05fRkxBR1N9IgpGQ0ZMQUdT
PSIke0NPTU1PTl9GTEFHU30iCkZGTEFHUz0iJHtDT01NT05fRkxBR1N9IgoKIyBOT1RFOiBUaGlz
IHN0YWdlIHdhcyBidWlsdCB3aXRoIHRoZSBiaW5kaXN0IFVzZSBmbGFnIGVuYWJsZWQKUE9SVERJ
Uj0iL3Zhci9kYi9yZXBvcy9nZW50b28iCkRJU1RESVI9Ii92YXIvY2FjaGUvZGlzdGZpbGVzIgpQ
S0dESVI9Ii92YXIvY2FjaGUvYmlucGtncyIKCiMgVGhpcyBzZXRzIHRoZSBsYW5ndWFnZSBvZiBi
dWlsZCBvdXRwdXQgdG8gRW5nbGlzaC4KIyBQbGVhc2Uga2VlcCB0aGlzIHNldHRpbmcgaW50YWN0
IHdoZW4gcmVwb3J0aW5nIGJ1Z3MuCkxDX01FU1NBR0VTPUMKCkNQVV9GTEFHU19YODY9ImFlcyBh
dnggYXZ4MiBmMTZjIGZtYTMgbW14IG1teGV4dCBwY2xtdWwgcG9wY250IHNzZSBzc2UyIHNzZTMg
c3NlNF8xIHNzZTRfMiBzc3NlMyIKCk1BS0VPUFRTPSItajEyIgoKIyBUT0RPOiBBZGQgbWlycm9y
cwojR0VOVE9PX01JUlJPUlM9IiIKVklERU9fQ0FSRFM9ImludGVsIGk5NjUgbnZpZGlhIgo=" \
	| base64 --decode > /etc/portage/make.conf
}

function chroot_common_prepare() {
	emerge-webrsync
	emerge --sync --quiet
	# Select GNOME as DE
	eselect profile set default/linux/amd64/17.1/desktop/gnome/systemd
	# Update the @world set
	emerge --ask --verbose --update --deep --newuse @world
}

function chroot_timezone() {
	echo "$TIMEZONE" > /etc/timezone
	emerge --config sys-libs/timezone-data
}

function chroot_locale() {
	echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
	locale-gen
	eselect locale set en_US.utf8
	env-update
	source /etc/profile
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
#main
