if [[ -z ${BSH_BUILD_PLATFORM-} ]]; then
	>&2 echo "BSH_BUILD_PLATFORM not set"
	exit 1
fi
if [[ -z ${BSH_HOST_ARCH-} ]]; then
	>&2 echo "BSH_HOST_ARCH not set"
	exit 1
fi
if [[ -z ${BSH_HOST_PLATFORM-} ]]; then
	>&2 echo "BSH_HOST_PLATFORM not set"
	exit 1
fi
if [[ -z ${BSH_HOST_LIBC-} ]]; then
	>&2 echo "BSH_HOST_LIBC not set"
	exit 1
fi
if [[ -z ${BSH_STATIC_DYNAMIC-} ]]; then
	>&2 echo "BSH_STATIC_DYNAMIC not set"
	exit 1
fi
if [[ -z ${BSH_DEBUG_RELEASE-} ]]; then
	>&2 echo "BSH_DEBUG_RELEASE not set"
	exit 1
fi
if [[ -z ${BSH_VTAG-} ]]; then
	>&2 echo "BSH_VTAG not set"
	exit 1
fi

temp_dir=temp
zip_root=tpt-libs-prebuilt-$BSH_HOST_ARCH-$BSH_HOST_PLATFORM-$BSH_HOST_LIBC-$BSH_STATIC_DYNAMIC-$BSH_DEBUG_RELEASE-$BSH_VTAG
zip_out=libraries.zip
wrap_out=libraries.wrap
