#!/bin/bash

# Download the latest stage3 tarball
function stage3_download() {
	echo "Downloading stage 3 archive..."

	# Get latest stage3 name
	latest_stage_name=$(wget --quiet "http://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64.txt"  -O- | tail -n 1 | cut -d " " -f 1)

	# Download stage3
	wget -q --show-progress "http://distfiles.gentoo.org/releases/amd64/autobuilds/$latest_stage_name"
	wget -q --show-progress "http://distfiles.gentoo.org/releases/amd64/autobuilds/$latest_stage_name.DIGESTS.asc"

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

	# Extract downloaded stag3
	tar xpf "stage3-"*".tar.xz" --xattrs-include='*.*' --numeric-owner
	# We don't need stage3 archive anymore. Remove it
	stage3_remove

	echo "Stage3 downloaded, verified and successfully extraced."
}

function stage3_remove() {
	rm stage3-*.tar.xz*
}

function mount_fs() {
	# Mounting the necessary filesystems
	# TODO: 1. /mnt/gentoo(/boot) before
	#       2. Replace hardcoded /mnt/gentoo path with variable
	mount --types proc /proc /mnt/gentoo/proc
	mount --rbind /sys /mnt/gentoo/sys
	mount --make-rslave /mnt/gentoo/sys
	mount --rbind /dev /mnt/gentoo/dev
	mount --make-rslave /mnt/gentoo/dev

	echo "All the necessary filesystems are mounted successfully "
}

stage3_download
#stage3_remove

