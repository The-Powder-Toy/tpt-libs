if [ -z "${PLATFORM_SHORT-}" ]; then
	>&2 echo "PLATFORM_SHORT not set (lin, mac, win)"
	exit 1
fi
if [ -z "${MACHINE_SHORT-}" ]; then
	>&2 echo "MACHINE_SHORT not set (x86_64, i686)"
	exit 1
fi
if [ -z "${TOOLSET_SHORT-}" ]; then
	>&2 echo "TOOLSET_SHORT not set (gcc, clang, mingw)"
	exit 1
fi
if [ -z "${STATIC_DYNAMIC-}" ]; then
	>&2 echo "STATIC_DYNAMIC not set (static, dynamic)"
	exit 1
fi

quad=${MACHINE_SHORT}-${PLATFORM_SHORT}-${TOOLSET_SHORT}-${STATIC_DYNAMIC}
zip_root=tpt-libs-prebuilt-$quad
zip_out=$temp_base/libraries.zip
wrap_out=$temp_base/libraries.wrap

tarball_hash() {
	case $1 in
	zlib-1.2.11.tar.gz)        sha256sum=c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1;;
	fftw-3.3.8.tar.gz)         sha256sum=6113262f6e92c5bd474f2875fa1b01054c4ad5040f6b0da7c03c98821d9ae303;;
	lua-5.1.5.tar.gz)          sha256sum=2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333;;
	lua-5.2.4.tar.gz)          sha256sum=b9e2e4aad6789b3b63a056d442f7b39f0ecfca3ae0f1fc0ae4e9614401b69f4b;;
	LuaJIT-2.1.0-beta3.tar.gz) sha256sum=1ad2e34b111c802f9d0cdf019e986909123237a28c746b21295b63c9e785d9c3;;
	curl-7.68.0.tar.gz)        sha256sum=1dd7604e418b0b9a9077f62f763f6684c1b092a7bc17e3f354b8ad5c964d7358;;
	SDL2-2.0.10.tar.gz)        sha256sum=b4656c13a1f0d0023ae2f4a9cf08ec92fffb464e0f24238337784159b8b91d57;;
	*)                     >&2 echo "no such tarball (update tarball_hash in common/common.sh)" && exit 1;;
	esac
}

get_and_cd() {
	tarball_hash $1
	mkdir $temp_base/lib
	cd $temp_base/lib
	tarball=../../tarballs/$1
	patch=../../patches/$quad/$1.patch
	# note that the sha256 sums in this script are only for checking integrity
	# (i.e. forcing the script to break in a predictable way if something
	# changes upstream), not for cryptographic verification; there is of course
	# no reason to validate the tarballs if they come right from the repo, but
	# it is useful if you choose to not trust those and download ones yourself
	echo $sha256sum $tarball | sha256sum -c
	tar xzf $tarball
	if [ -z "${skip_patch-}" ] && [ -f $patch ]; then
		num=0
		if cat $patch | head -n 1 | grep .before; then # patchtool.sh patches
			num=2
		fi
		patch -p$num -i $patch
	fi
	cd *
}

uncd_and_unget() {
	cd ../../..
	rm -r $temp_base/lib
}
