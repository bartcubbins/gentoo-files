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
	gpg --keyserver hkps.pool.sks-keyservers.net --recv-keys 0xBB572E0E2D182910
	gpg --verify "stage3-"*".tar.xz.DIGESTS.asc"
	grep $(sha512sum "stage3-"*".tar.xz") "stage3-"*".tar.xz.DIGESTS.asc" > result
	if [ $? -ne 0 ]; then
		echo "Failed! Remove downloaded stage3 and exit."
		stage3_remove
		exit 1
	fi
	echo "Success."
}

function stage3_remove() {
	rm stage3-*.tar.xz*
}

stage3_download
stage3_remove

