#!/usr/bin/env bash

set -euo pipefail
shopt -s globstar
IFS=$'\n\t'

# goals:
#  - libs have debug info
#  - release libs are optimized
#  - static libs are static
#  - only necessary files are packaged
#  - windows libs use the same crt as the exe
#  - exes can be run from build sites
#  - luas are c++-aware
#  - libcurl uses zlib

. ./.github/common.sh

if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-mingw ]] && [[ -z $MSYSTEM ]]; then
	exec 'C:\msys64\ucrt64.exe' '-c' $0
	exit 1
fi

repo=$(realpath .)

tarball_hash() {
	local tarball_name=$1
	case $tarball_name in
	zlib-1.2.11.tar.gz)        sha256sum=c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1;; # acquired from https://zlib.net/zlib-1.2.11.tar.gz
	fftw-3.3.8.tar.gz)         sha256sum=6113262f6e92c5bd474f2875fa1b01054c4ad5040f6b0da7c03c98821d9ae303;; # acquired from http://www.fftw.org/fftw-3.3.8.tar.gz (eww http)
	lua-5.1.5.tar.gz)          sha256sum=2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333;; # acquired from https://www.lua.org/ftp/lua-5.1.5.tar.gz
	lua-5.2.4.tar.gz)          sha256sum=b9e2e4aad6789b3b63a056d442f7b39f0ecfca3ae0f1fc0ae4e9614401b69f4b;; # acquired from https://www.lua.org/ftp/lua-5.2.4.tar.gz
	LuaJIT-2.1.0-git.tar.gz)   sha256sum=d88203e0517df7e1981c8fd3ecb5abd5df1b1c34316160b8842eec7d4be398c6;; # acquired from https://luajit.org/git/luajit.git with git archive --format=tar.gz --prefix=LuaJIT-2.1.0-git/ d06beb0480c5
	curl-8.10.1.tar.gz)        sha256sum=d15ebab765d793e2e96db090f0e172d127859d78ca6f6391d7eafecfd894bbc0;; # acquired from https://curl.se/download/curl-8.10.1.tar.gz
	SDL2-2.30.9.tar.gz)        sha256sum=24b574f71c87a763f50704bbb630cbe38298d544a1f890f099a4696b1d6beba4;; # acquired from https://github.com/libsdl-org/SDL/releases/download/release-2.30.9/SDL2-2.30.9.tar.gz
	libpng-1.6.37.tar.gz)      sha256sum=daeb2620d829575513e35fecc83f0d3791a620b9b93d800b763542ece9390fb4;; # acquired from https://download.sourceforge.net/libpng/libpng-1.6.37.tar.gz
	mbedtls-3.6.2.tar.bz2)     sha256sum=8b54fb9bcf4d5a7078028e0520acddefb7900b3e66fec7f7175bb5b7d85ccdca;; # acquired from https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-3.6.2/mbedtls-3.6.2.tar.bz2
	jsoncpp-1.9.5.tar.gz)      sha256sum=f409856e5920c18d0c2fb85276e24ee607d2a09b5e7d5f0a371368903c275da2;; # acquired from https://github.com/open-source-parsers/jsoncpp/archive/refs/tags/1.9.5.tar.gz
	bzip2-1.0.8.tar.gz)        sha256sum=ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269;; # acquired from https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
	nghttp2-1.50.0.tar.gz)     sha256sum=6de469efc8e9d47059327a6736aebe0a7d73f57e5e37ab4c4f838fb1eebd7889;; # acquired from https://github.com/nghttp2/nghttp2/archive/refs/tags/v1.50.0.tar.gz
	*)                                         >&2 echo "no such tarball (update tarball_hash)" && exit 1;;
	esac
}

get_and_cd() {
	local tarball_name=$1
	if ! [[ -z "${2-}" ]]; then
		declare -n version_ptr=$2
		version_ptr=$(basename -s .tar.gz $tarball_name | cut -d '-' -f 2-)
	fi
	local lib_dir=lib.$tarball_name
	tarball_hash $tarball_name
	mkdir $temp_dir/$lib_dir
	cd $temp_dir/$lib_dir
	local tarball=../../tarballs/$tarball_name
	# note that the sha256 sums in this script are only for checking integrity
	# (i.e. forcing the script to break in a predictable way if something
	# changes upstream), not for cryptographic verification; there is of course
	# no reason to validate the tarballs if they come right from the repo, but
	# it is useful if you choose to not trust those and download ones yourself
	echo $sha256sum $tarball | sha256sum -c
	tar -xf $tarball
	cd *
}

uncd_and_unget() {
	cd ../../..
}

if [[ -z ${NPROC-} ]]; then
	NPROC=$(nproc)
fi

if [[ $BSH_DEBUG_RELEASE == release ]]; then
	debug_d=
	debug_hd=
else
	debug_d=d
	debug_hd=-d
fi

case $BSH_HOST_ARCH-$BSH_HOST_PLATFORM-$BSH_HOST_LIBC-$BSH_STATIC_DYNAMIC in
x86_64-linux-gnu-static) ;;
aarch64-linux-gnu-static) ;;
x86_64-windows-mingw-static) ;;
x86_64-windows-msvc-static) ;;
x86_64-windows-msvc-dynamic) ;;
x86-windows-msvc-static) ;;
x86-windows-msvc-dynamic) ;;
aarch64-windows-msvc-static) ;;
aarch64-windows-msvc-dynamic) ;;
x86_64-darwin-macos-static) ;;
aarch64-darwin-macos-static) ;;
x86-android-bionic-static) ;;
x86_64-android-bionic-static) ;;
arm-android-bionic-static) ;;
aarch64-android-bionic-static) ;;
wasm32-emscripten-emscripten-static) ;;
*) >&2 echo "configuration $BSH_HOST_ARCH-$BSH_HOST_PLATFORM-$BSH_HOST_LIBC-$BSH_STATIC_DYNAMIC is not supported" && exit 1;;
esac

android_platform=none
if [[ $BSH_HOST_PLATFORM == android ]]; then
	android_platform=android-31
	if [[ -z "${JAVA_HOME_8_X64-}" ]]; then
		>&2 echo "JAVA_HOME_8_X64 not set"
		exit 1
	fi
	if [[ -z "${ANDROID_SDK_ROOT-}" ]]; then
		>&2 echo "ANDROID_SDK_ROOT not set"
		exit 1
	fi
	if [[ -z "${ANDROID_NDK_LATEST_HOME-}" ]]; then
		>&2 echo "ANDROID_NDK_LATEST_HOME not set"
		exit 1
	fi
fi

if [[ -z ${BSH_NO_PACKAGES-} ]]; then
	case $BSH_HOST_PLATFORM in
	linux)
		if [[ $BSH_BUILD_PLATFORM-$BSH_HOST_LIBC == windows-mingw ]]; then
			pacman -S --noconfirm --needed mingw-w64-ucrt-x86_64-gcc
		else
			sudo apt update
			sudo apt install libc6-dev fcitx-libs-dev libibus-1.0-dev libwayland-dev libxkbcommon-dev libegl-dev libxrandr-dev
		fi
		;;
	windows)
		if [[ $BSH_BUILD_PLATFORM-$BSH_HOST_LIBC == windows-mingw ]]; then
			pacman -S --noconfirm --needed mingw-w64-ucrt-x86_64-{gcc,cmake,make,ninja,7zip} patch
		fi
		;;
	android)
		sudo apt update
		case $BSH_HOST_ARCH in
		x86_64)  ;&
		aarch64) sudo apt install libc6-dev;;
		x86)     ;&
		arm)     sudo apt install libc6-dev-i386;;
		esac
		(
			export PATH=$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/tools/bin:$PATH
			sdkmanager "platforms;$android_platform"
		)
		;;
	emscripten)
		git clone https://github.com/emscripten-core/emsdk.git --branch 3.1.30
		cd emsdk
		./emsdk install latest
		./emsdk activate latest
		. ./emsdk_env.sh
		export EMROOT=$EMSDK/upstream/emscripten
		cd ..
		;;
	esac
fi

if [[ $BSH_HOST_PLATFORM == android ]]; then
	android_platform_jar=$ANDROID_SDK_ROOT/platforms/$android_platform/android.jar
	if ! [[ -f $android_platform_jar ]]; then
		>&2 echo "$android_platform_jar not found"
		exit 1
	fi
fi

if [[ $BSH_HOST_PLATFORM == emscripten ]]; then
	if [[ -z "${EMROOT-}" ]]; then
		>&2 echo "EMROOT not set"
		exit 1
	fi
fi

meson_dirs_configure=
meson_dirs_configure+=$'\t'-Dbindir=bin
meson_dirs_configure+=$'\t'-Dlibdir=lib
meson_dirs_configure+=$'\t'-Dincludedir=include
meson_dirs_configure+=$'\t'-Ddatadir=junk.datadir
meson_dirs_configure+=$'\t'-Dinfodir=junk.infodir
meson_dirs_configure+=$'\t'-Dlocaledir=junk.localedir
meson_dirs_configure+=$'\t'-Dlibexecdir=junk.libexecdir
meson_dirs_configure+=$'\t'-Dlocalstatedir=junk.localstatedir
meson_dirs_configure+=$'\t'-Dmandir=junk.mandir
meson_dirs_configure+=$'\t'-Dsbindir=junk.sbindir
meson_dirs_configure+=$'\t'-Dsharedstatedir=junk.sharedstatedir
meson_dirs_configure+=$'\t'-Dsysconfdir=junk.sysconfdir

function export_path() {
	local path=$1
	if [[ $BSH_BUILD_PLATFORM == windows ]]; then
		cygpath -m $path
	else
		echo $path
	fi
}

meson_cross_configure=
if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
	case $BSH_HOST_ARCH in
	x86_64)  vs_env_arch=x64      ; cmake_vs_toolset=v141; vcvars_ver=14.2;;
	x86)     vs_env_arch=x86      ; cmake_vs_toolset=v141; vcvars_ver=14.2;;
	aarch64) vs_env_arch=x64_arm64; cmake_vs_toolset=v143; vcvars_ver=14.4;;
	esac
	cmake_vs_toolset=${BSH_VS_TOOLSET_CMAKE-$cmake_vs_toolset}
	VS_ENV_PARAMS=$vs_env_arch$'\t'-vcvars_ver=${BSH_VS_TOOLSET-$vcvars_ver}
	. ./.github/vs-env.sh
	if [[ $BSH_HOST_ARCH == aarch64 ]]; then
		meson_cross_configure+=$'\t'--cross-file=$(export_path $repo/.github/msvca64-ghactions.ini)
	fi
elif [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-mingw ]]; then
	if [[ $BSH_BUILD_PLATFORM == linux ]]; then
		meson_cross_configure+=$'\t'--cross-file=$repo/.github/mingw-ghactions.ini
	fi
	export CC=x86_64-w64-mingw32-gcc
	export CXX=x86_64-w64-mingw32-g++
elif [[ $BSH_HOST_PLATFORM == darwin ]]; then
	# may need export SDKROOT=$(xcrun --show-sdk-path --sdk macosx11.1)
	CC=clang
	CXX=clang++
	OBJC=clang
	OBJCXX=clang++
	if [[ $BSH_HOST_ARCH == aarch64 ]]; then
		export MACOSX_DEPLOYMENT_TARGET=11.0
		CC+=" -arch arm64"
		CXX+=" -arch arm64"
		OBJC+=" -arch arm64"
		OBJCXX+=" -arch arm64"
		meson_cross_configure+=$'\t'--cross-file=$repo/.github/macaa64-ghactions.ini
	else
		export MACOSX_DEPLOYMENT_TARGET=10.13
		CC+=" -arch x86_64"
		CXX+=" -arch x86_64"
		OBJC+=" -arch x86_64"
		OBJCXX+=" -arch x86_64"
	fi
	export CC
	export CXX
	export OBJC
	export OBJCXX
elif [[ $BSH_HOST_PLATFORM == emscripten ]]; then
	EMCC_CFLAGS="-s USE_PTHREADS=1" # for cmake
	CC="emcc $EMCC_CFLAGS" # for everything else
	EMCC_CXXFLAGS="-s DISABLE_EXCEPTION_CATCHING=0 -s USE_PTHREADS=1" # for cmake
	CXX="em++ $EMCC_CXXFLAGS" # for everything else
	AR=emar
	export CC
	export CXX
	export AR
elif [[ $BSH_HOST_PLATFORM == android ]]; then
	case $BSH_HOST_ARCH in
	x86_64)  android_toolchain_prefix=x86_64-linux-android    ; android_system_version=21; android_arch_abi=x86_64     ;;
	x86)     android_toolchain_prefix=i686-linux-android      ; android_system_version=21; android_arch_abi=x86        ;;
	aarch64) android_toolchain_prefix=aarch64-linux-android   ; android_system_version=21; android_arch_abi=arm64-v8a  ;;
	arm)     android_toolchain_prefix=armv7a-linux-androideabi; android_system_version=21; android_arch_abi=armeabi-v7a;;
	esac
	android_toolchain_dir=$ANDROID_NDK_LATEST_HOME/toolchains/llvm/prebuilt/linux-x86_64
	CC=$android_toolchain_dir/bin/$android_toolchain_prefix$android_system_version-clang
	CXX=$android_toolchain_dir/bin/$android_toolchain_prefix$android_system_version-clang++
	LD=$android_toolchain_dir/bin/$android_toolchain_prefix-ld
	AR=$android_toolchain_dir/bin/llvm-ar
	CC+=" -fPIC"
	CXX+=" -fPIC"
	LD+=" -fPIC"
	export CC
	export CXX
	export LD
	export AR
	meson_cross_configure+=$'\t'--cross-file=$repo/.github/android/cross/$BSH_HOST_ARCH.ini
	cat << ANDROID_INI > .github/android-ghactions.ini
[constants]
andriod_ndk_toolchain_bin = '$ANDROID_NDK_LATEST_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin'

[properties]
# android_ndk_toolchain_prefix comes from the correct cross-file in ./android/cross
android_ndk_toolchain_prefix = android_ndk_toolchain_prefix

[binaries]
c = andriod_ndk_toolchain_bin / (android_ndk_toolchain_prefix + 'clang')
cpp = andriod_ndk_toolchain_bin / (android_ndk_toolchain_prefix + 'clang++')
strip = andriod_ndk_toolchain_bin / 'llvm-strip'
ANDROID_INI
	meson_cross_configure+=$'\t'--cross-file=$repo/.github/android-ghactions.ini
else
	export CC=gcc
	export CXX=g++
fi
CFLAGS=
if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC != windows-msvc ]]; then
	CFLAGS+=" -ffunction-sections -fdata-sections"
fi
export CFLAGS
export CXXFLAGS=$CFLAGS

function check_program() {
	local program_name=$1
	which $program_name > /dev/null || (>&2 echo "can't find $program_name or similar" && exit 1)
}

make=make
if which mingw32-make; then
	make=mingw32-make
fi
check_program cmake
check_program 7z
if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
	check_program meson
	check_program ninja
else
	check_program $make
fi

if [[ -d $temp_dir ]]; then
	rm -r $temp_dir
fi
mkdir $temp_dir
cp -r zip_stub $temp_dir/$zip_root
mkdir $temp_dir/$zip_root/licenses
temp_dir_real=$(realpath $temp_dir)
zip_root_real=$temp_dir_real/$zip_root
library_versions=

patches_real=$(realpath patches)
# use like patch_breakpoint $patches_real/libpng-pkg-config-prefix.patch apply
# or  like patch_breakpoint $patches_real/libpng-pkg-config-prefix.patch apply_and_edit

function interactive_breakpoint() {
	bpname=${1-(none)}
	>&2 echo ============== entering interactive breakpoint $bpname ==============
	if ! bash; then
		>&2 echo ============== exiting from interactive breakpoint $bpname due to nonzero exit code ==============
		exit 1
	fi
	>&2 echo ============== leaving interactive breakpoint $bpname ==============
}

function inplace_sed() {
	local subst=$1
	local path=$2
	if [[ $BSH_BUILD_PLATFORM == darwin ]]; then
		sed -i "" -e $subst $path
	else
		sed -i $subst $path
	fi
}

function dos2unix() {
	inplace_sed 's/\r//' $1
}

function angry_patch() {
	>&2 echo "fixing line endings in $1 because patch is not competent enough to do it on its own"
	patched_patch=$temp_dir_real/.patched_patch
	cp $1 $patched_patch
	dos2unix $patched_patch
	for line in $(grep $patched_patch -Fe "--- "); do # not perfect but I don't care
		file="$(echo "$line" | cut -d ' ' -f 2 | cut -d '/' -f 2-)"
		if [[ -f "$file" ]]; then
			>&2 echo "fixing line endings in $file because patch is not competent enough to do it on its own"
			dos2unix "$file"
		fi
	done
	patch -p1 -i $patched_patch
	rm $patched_patch
}

function add_install_flags() {
	declare -n cmake_configure_ptr=$1
	cmake_configure_ptr+=$'\t'-DCMAKE_INSTALL_PREFIX=$(export_path $zip_root_real)
	cmake_configure_ptr+=$'\t'-DCMAKE_INSTALL_LIBDIR=lib
	cmake_configure_ptr+=$'\t'-DCMAKE_INSTALL_INCLUDEDIR=include
	cmake_configure_ptr+=$'\t'-DCMAKE_INSTALL_BINDIR=bin
	cmake_configure_ptr+=$'\t'-DCMAKE_INSTALL_SBINDIR=junk.sbindir
	cmake_configure_ptr+=$'\t'-DCMAKE_INSTALL_LIBEXECDIR=junk.libexecdir
	cmake_configure_ptr+=$'\t'-DCMAKE_INSTALL_SYSCONFDIR=junk.sysconfdir
	cmake_configure_ptr+=$'\t'-DCMAKE_INSTALL_SHAREDSTATEDIR=junk.sharedstatedir
	cmake_configure_ptr+=$'\t'-DCMAKE_INSTALL_LOCALSTATEDIR=junk.localstatedir
	cmake_configure_ptr+=$'\t'-DCMAKE_INSTALL_RUNSTATEDIR=junk.runstatedir
	cmake_configure_ptr+=$'\t'-DCMAKE_INSTALL_OLDINCLUDEDIR=junk.oldincludedir
	cmake_configure_ptr+=$'\t'-DCMAKE_INSTALL_DATAROOTDIR=junk.datarootdir
	cmake_configure_ptr+=$'\t'-DCMAKE_INSTALL_DATADIR=junk.datadir
	cmake_configure_ptr+=$'\t'-DCMAKE_INSTALL_INFODIR=junk.infodir
	cmake_configure_ptr+=$'\t'-DCMAKE_INSTALL_LOCALEDIR=junk.localedir
	cmake_configure_ptr+=$'\t'-DCMAKE_INSTALL_MANDIR=junk.mandir
	cmake_configure_ptr+=$'\t'-DCMAKE_INSTALL_DOCDIR=junk.docdir
}

function add_android_flags() {
	declare -n cmake_configure_ptr=$1
	cmake_configure_ptr+=$'\t'-DANDROID_ABI=$android_arch_abi
	cmake_configure_ptr+=$'\t'-DANDROID_PLATFORM=android-$android_system_version
	cmake_configure_ptr+=$'\t'-DCMAKE_TOOLCHAIN_FILE=$(export_path $ANDROID_NDK_LATEST_HOME/build/cmake/android.toolchain.cmake)
}

function add_emscripten_flags() {
	declare -n cmake_configure_ptr=$1
	cmake_configure_ptr+=$'\t'-DCMAKE_TOOLCHAIN_FILE=$EMROOT/cmake/Modules/Platform/Emscripten.cmake
}

function patch_breakpoint() {
	local patch_path=$1
	local mode=$2
	local dir_name=$(basename $PWD)
	case $mode in
	apply) ;;
	apply_and_edit)
		cd ..
		cp -r $dir_name $dir_name.old
		mv $dir_name $dir_name.new
		cd $dir_name.new
		;;
	esac
	if [[ -f $patch_path ]]; then
		>&2 echo ============== applying patch $patch_path ==============
		angry_patch $patch_path
	fi
	case $mode in
	apply) ;;
	apply_and_edit)
		>&2 echo ============== entering patch edit mode ==============
		if [[ -f $patch_path ]]; then
			>&2 echo ============== begin old patch content ==============
			>&2 cat $patch_path
			>&2 echo ============== end old patch content ==============
		else
			>&2 echo ============== no patch file, patch not invoked ==============
		fi
		interactive_breakpoint patchme
		cd ..
		set +e
		diff --strip-trailing-cr -Naur $dir_name.old $dir_name.new > $patch_path
		local diff_code=$?
		set -e
		if [[ $diff_code == 1 ]]; then
			>&2 echo ============== begin new patch content ==============
			>&2 cat $patch_path
			>&2 echo ============== end new patch content ==============
		else
			[[ $diff_code = 0 ]]
			>&2 echo ============== no difference, removing patch file ==============
			rm $patch_path
		fi
		rm -r $dir_name.old
		mv $dir_name.new $dir_name
		cd $dir_name
		>&2 echo ============== leaving patch edit mode ==============
		;;
	esac
}

cmake_build_type=
case $BSH_DEBUG_RELEASE in
debug)
	cmake_build_type=Debug
	cmake_msvc_rt=MultiThreadedDebug
	;;
release)
	cmake_build_type=RelWithDebInfo
	cmake_msvc_rt=MultiThreaded
	;;
esac
msvc_rt=
case $BSH_STATIC_DYNAMIC-$BSH_DEBUG_RELEASE in
dynamic-debug) msvc_rt=MDd;;
dynamic-release) msvc_rt=MD;;
static-debug) msvc_rt=MTd;;
static-release) msvc_rt=MT;;
esac

function windows_msvc_static_mt() {
	inplace_sed 's|/MD|/MT|g' CMakeCache.txt # static msvcrt
}

function compile_zlib() {
	if [[ $BSH_HOST_PLATFORM == emscripten ]]; then
		return
	fi
	get_and_cd zlib-1.2.11.tar.gz zlib_version
	patch_breakpoint $patches_real/zlib-install-dirs.patch apply
	if [[ $BSH_HOST_PLATFORM != windows ]]; then
		patch_breakpoint $patches_real/zlib-gz-intmax-visibility.patch apply
	fi
	mkdir build
	cmake_configure=cmake # not local because add_*_flags can't deal with that
	cmake_configure+=$'\t'-G$'\t'Ninja
	cmake_configure+=$'\t'-DCMAKE_BUILD_TYPE=$cmake_build_type
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		cmake_configure+=$'\t'-DCMAKE_VS_PLATFORM_TOOLSET=$cmake_vs_toolset
	fi
	add_install_flags cmake_configure
	cd build
	echo VERBOSE=1 $cmake_configure ..
	VERBOSE=1 $cmake_configure ..
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC-$BSH_STATIC_DYNAMIC == windows-msvc-static ]]; then
		windows_msvc_static_mt
	fi
	VERBOSE=1 cmake --build . -j$NPROC --config $cmake_build_type
	VERBOSE=1 cmake --install . --config $cmake_build_type
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		cp **/zlib*.pdb $zip_root_real/lib
	fi
	cd ..
	echo 7960b6b1cc63e619abb77acaea5427159605afee8c8b362664f4effc7d7f7d15 README | sha256sum -c
	sed -n 85,106p README > $zip_root_real/licenses/zlib.LICENSE
	uncd_and_unget
	library_versions+="zlib_version = '$zlib_version-tpt-libs'"$'\n'
}

function compile_mbedtls() {
	if [[ $BSH_HOST_PLATFORM == darwin ]] || [[ $BSH_HOST_PLATFORM == emscripten ]]; then
		return
	fi
	get_and_cd mbedtls-3.6.2.tar.bz2 mbedtls_version
	mkdir build
	cmake_configure=cmake # not local because add_*_flags can't deal with that
	cmake_configure+=$'\t'-G$'\t'Ninja
	cmake_configure+=$'\t'-DCMAKE_BUILD_TYPE=$cmake_build_type
	cmake_configure+=$'\t'-DENABLE_PROGRAMS=OFF
	cmake_configure+=$'\t'-DMBEDTLS_FATAL_WARNINGS=OFF
	cmake_configure+=$'\t'-DENABLE_TESTING=OFF
	# if [[ $BSH_STATIC_DYNAMIC == dynamic ]]; then
	# 	# nothing; mbedtls is always static
	#	# I couldn't get dynamic to work on windows, the dll exports nothing...
	# fi
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC-$BSH_STATIC_DYNAMIC == windows-msvc-static ]]; then
		cmake_configure+=$'\t'-DMSVC_STATIC_RUNTIME=ON
	fi
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		cmake_configure+=$'\t'-DCMAKE_VS_PLATFORM_TOOLSET=$cmake_vs_toolset
	fi
	add_install_flags cmake_configure
	cd build
	VERBOSE=1 $cmake_configure ..
	VERBOSE=1 cmake --build . -j$NPROC --config $cmake_build_type
	VERBOSE=1 cmake --install . --config $cmake_build_type
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		cp **/mbed*.pdb $zip_root_real/lib
	fi
	cd ..
	echo 9b405ef4c89342f5eae1dd828882f931747f71001cfba7d114801039b52ad09b LICENSE | sha256sum -c
	cp LICENSE $zip_root_real/licenses/mbedtls.LICENSE
	uncd_and_unget
}

function compile_libpng() {
	if [[ $BSH_HOST_PLATFORM == emscripten ]]; then
		return
	fi
	get_and_cd libpng-1.6.37.tar.gz libpng_version
	libpng_version+="+zlib-$zlib_version"
	patch_breakpoint $patches_real/libpng-install-dirs.patch apply
	mkdir build
	cmake_configure=cmake # not local because add_*_flags can't deal with that
	cmake_configure+=$'\t'-G$'\t'Ninja
	cmake_configure+=$'\t'-DCMAKE_BUILD_TYPE=$cmake_build_type
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		cmake_configure+=$'\t'-DCMAKE_VS_PLATFORM_TOOLSET=$cmake_vs_toolset
	fi
	add_install_flags cmake_configure
	cmake_configure+=$'\t'-DPNG_BUILD_ZLIB=ON
	cmake_configure+=$'\t'-DZLIB_INCLUDE_DIR=$(export_path $zip_root_real/include)
	if [[ $BSH_HOST_ARCH == arm ]] || [[ $BSH_HOST_ARCH == aarch64 ]]; then
		patch_breakpoint $patches_real/libpng-arm-no-neon.patch apply
	fi
	if [[ $BSH_HOST_PLATFORM == android ]]; then
		add_android_flags cmake_configure
	fi
	if [[ $BSH_HOST_PLATFORM == windows ]]; then
		local zlib_path
		case $BSH_HOST_LIBC-$BSH_STATIC_DYNAMIC in
		msvc-static) zlib_path=$zip_root_real/lib/zlibstatic.lib;;
		msvc-dynamic) zlib_path=$zip_root_real/lib/zlib$debug_d.lib;;
		mingw-static) zlib_path=$zip_root_real/lib/libzlibstatic.a;;
		esac
		cmake_configure+=$'\t'-DZLIB_LIBRARY=$(export_path $zlib_path)
	fi
	if [[ $BSH_STATIC_DYNAMIC == static ]]; then
		cmake_configure+=$'\t'-DPNG_SHARED=OFF
	fi
	cd build
	VERBOSE=1 $cmake_configure ..
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC-$BSH_STATIC_DYNAMIC == windows-msvc-static ]]; then
		windows_msvc_static_mt
	fi
	VERBOSE=1 cmake --build . -j$NPROC --config $cmake_build_type
	VERBOSE=1 cmake --install . --config $cmake_build_type
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		cp **/*png*.pdb $zip_root_real/lib
	fi
	cd ..
	echo bf5e22b9dce8464064ae17a48ea1133c3369ac9e1d80ef9e320e5219aa14ea9b LICENSE | sha256sum -c
	cp LICENSE $zip_root_real/licenses/libpng.LICENSE
	uncd_and_unget
	library_versions+="libpng_version = '$libpng_version-tpt-libs'"$'\n'
}

function compile_curl() {
	if [[ $BSH_HOST_PLATFORM == emscripten ]]; then
		return
	fi
	get_and_cd curl-8.10.1.tar.gz curl_version
	patch_breakpoint $patches_real/curl-mbedtls-usage.patch apply
	curl_version+="+nghttp2-$nghttp2_version"
	curl_version+="+zlib-$zlib_version"
	mkdir build
	cmake_configure=cmake # not local because add_*_flags can't deal with that
	cmake_configure+=$'\t'-G$'\t'Ninja
	cmake_configure+=$'\t'-DBUILD_TESTING=OFF
	cmake_configure+=$'\t'-DBUILD_LIBCURL_DOCS=OFF
	cmake_configure+=$'\t'-DENABLE_CURL_MANUAL=OFF
	cmake_configure+=$'\t'-DCMAKE_BUILD_TYPE=$cmake_build_type
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		cmake_configure+=$'\t'-DCMAKE_VS_PLATFORM_TOOLSET=$cmake_vs_toolset
	fi
	add_install_flags cmake_configure
	cmake_configure+=$'\t'-DCURL_USE_LIBSSH2=OFF
	cmake_configure+=$'\t'-DCURL_USE_LIBPSL=OFF
	cmake_configure+=$'\t'-DUSE_LIBIDN2=OFF
	cmake_configure+=$'\t'-DBUILD_CURL_EXE=OFF
	cmake_configure+=$'\t'-DHTTP_ONLY=ON
	cmake_configure+=$'\t'-DUSE_NGHTTP2=ON
	if [[ $BSH_HOST_PLATFORM == windows ]]; then
		cmake_configure+=$'\t'-DCURL_USE_MBEDTLS=ON
		cmake_configure+=$'\t'-DCURL_CA_PATH=none
		cmake_configure+=$'\t'-DCMAKE_PDB_OUTPUT_DIRECTORY=$(export_path $(realpath build))
		curl_version+="+mbedtls-$mbedtls_version"
	fi
	if [[ $BSH_HOST_PLATFORM == darwin ]]; then
		cmake_configure+=$'\t'-DCURL_USE_SECTRANSP=ON
		cmake_configure+=$'\t'-DCURL_CA_PATH=none
	fi
	if [[ $BSH_HOST_PLATFORM == linux ]] || [[ $BSH_HOST_PLATFORM == android ]]; then
		cmake_configure+=$'\t'-DCURL_USE_MBEDTLS=ON
		cmake_configure+=$'\t'-DCURL_CA_PATH=none
		curl_version+="+mbedtls-$mbedtls_version"
	fi
	cmake_configure+=$'\t'-DCMAKE_PREFIX_PATH=$(export_path $zip_root_real)
	if [[ $BSH_STATIC_DYNAMIC == static ]]; then
		cmake_configure+=$'\t'-DBUILD_SHARED_LIBS=OFF
	fi
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC-$BSH_STATIC_DYNAMIC == windows-msvc-static ]]; then
		cmake_configure+=$'\t'-DCURL_STATIC_CRT=ON
	fi
	local curl_cflags=$CFLAGS
	if [[ $BSH_HOST_PLATFORM-$BSH_STATIC_DYNAMIC == windows-static ]]; then
		curl_cflags+=" -DNGHTTP2_STATICLIB"
	fi
	cd build
	CFLAGS=$curl_cflags VERBOSE=1 $cmake_configure ..
	VERBOSE=1 cmake --build . -j$NPROC --config $cmake_build_type
	VERBOSE=1 cmake --install . --config $cmake_build_type
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		if ! cp **/libcurl*.pdb $zip_root_real/lib; then
			# TODO: libcurl's cmake config does not set the pdb's name correctly so we grab anything we see
			cp **/*.pdb $zip_root_real/lib/libcurl.pdb
		fi
	fi
	cd ..
	echo adb1fc06547fd136244179809f7b7c2d2ae6c4534f160aa513af9b6a12866a32 COPYING | sha256sum -c
	cp COPYING $zip_root_real/licenses/libcurl.LICENSE
	uncd_and_unget
	library_versions+="curl_version = '$curl_version-tpt-libs'"$'\n'
}

function compile_sdl2() {
	if [[ $BSH_HOST_PLATFORM == emscripten ]]; then
		return
	fi
	get_and_cd SDL2-2.30.9.tar.gz sdl2_version
	patch_breakpoint $patches_real/sdl-no-dynapi.patch apply
	patch_breakpoint $patches_real/sdl-fix-haptic-inclusion.patch apply
	if [[ $BSH_HOST_PLATFORM == linux ]]; then
		patch_breakpoint $patches_real/sdl-linux-no-input-events.patch apply
	fi
	mkdir build
	cmake_configure=cmake # not local because add_*_flags can't deal with that
	cmake_configure+=$'\t'-G$'\t'Ninja
	cmake_configure+=$'\t'-DCMAKE_BUILD_TYPE=$cmake_build_type
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		cmake_configure+=$'\t'-DCMAKE_VS_PLATFORM_TOOLSET=$cmake_vs_toolset
	fi
	add_install_flags cmake_configure
	cmake_configure+=$'\t'-DSDL_AUDIO=OFF
	cmake_configure+=$'\t'-DSDL_POWER=OFF
	cmake_configure+=$'\t'-DSDL_LIBC=ON
	if [[ $BSH_HOST_PLATFORM == android ]]; then
		cmake_configure+=$'\t'-DSDL_STATIC_PIC=ON
		add_android_flags cmake_configure
	fi
	if [[ $BSH_HOST_PLATFORM == android ]]; then
		cmake_configure+=$'\t'-DSDL_HIDAPI=ON
		cmake_configure+=$'\t'-DSDL_HAPTIC=ON
		cmake_configure+=$'\t'-DSDL_JOYSTICK=ON
	else
		cmake_configure+=$'\t'-DSDL_HIDAPI=OFF
		cmake_configure+=$'\t'-DSDL_HAPTIC=OFF
		cmake_configure+=$'\t'-DSDL_JOYSTICK=OFF
	fi
	if [[ $BSH_STATIC_DYNAMIC == static ]]; then
		cmake_configure+=$'\t'-DSDL_STATIC=ON
		cmake_configure+=$'\t'-DSDL_SHARED=OFF
	else
		cmake_configure+=$'\t'-DSDL_STATIC=OFF
		cmake_configure+=$'\t'-DSDL_SHARED=ON
	fi
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC-$BSH_STATIC_DYNAMIC == windows-msvc-static ]]; then
		cmake_configure+=$'\t'-DSDL_FORCE_STATIC_VCRT=ON
	fi
	cd build
	VERBOSE=1 $cmake_configure ..
	VERBOSE=1 cmake --build . -j$NPROC --config $cmake_build_type
	VERBOSE=1 cmake --install . --config $cmake_build_type
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		cp **/SDL2*.pdb $zip_root_real/lib
	fi
	cd ..
	if [[ $BSH_HOST_PLATFORM == android ]]; then
		cd android-project/app/src/main/java
		patch_breakpoint $patches_real/sdl-android-only-powder-so.patch apply
		$JAVA_HOME_8_X64/bin/javac \
			-source 1.8 \
			-target 1.8 \
			-bootclasspath $JAVA_HOME_8_X64/jre/lib/rt.jar \
			-classpath $android_platform_jar \
			$(find . -name "*.java")
		$JAVA_HOME_8_X64/bin/jar cMf sdl.jar $(find . -name "*.class")
		cp sdl.jar $zip_root_real/lib
		cd ../../../../..
	fi
	echo 9b9e1764f06701bcf7ce21e942c682d5921ba0900c6fca760321b1c8837a9662 LICENSE.txt | sha256sum -c
	cp LICENSE.txt $zip_root_real/licenses/sdl2.LICENSE
	uncd_and_unget
	library_versions+="sdl2_version = '$sdl2_version-tpt-libs'"$'\n'
}

function compile_lua5x() {
	local subdir=$1
	patch_breakpoint $patches_real/$subdir-extern-c.patch apply
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		find . -name "*.c" -exec sh -c 'x="{}"; mv "$x" "${x}pp"' \; # compile as C++ despite .c extension
		patch_breakpoint $patches_real/$subdir-windows-msvc-meson.patch apply
		local meson_configure=meson$'\t'setup
		if [[ $BSH_DEBUG_RELEASE == release ]]; then
			meson_configure+=$'\t'-Dbuildtype=debugoptimized
		else
			meson_configure+=$'\t'-Dbuildtype=debug
		fi
		if [[ $BSH_STATIC_DYNAMIC == static ]]; then
			meson_configure+=$'\t'-Db_vscrt=static_from_buildtype
			meson_configure+=$'\t'-Ddefault_library=static
			meson_configure+=$'\t'-Dcpp_args="['/Z7']" # include debug info in the .lib
		else
			meson_configure+=$'\t'-Dcpp_args="['-DLUA_BUILD_AS_DLL']"
		fi
		meson_configure+=$meson_cross_configure
		meson_configure+=$meson_dirs_configure
		meson_configure+=$'\t'--prefix$'\t'$(export_path $zip_root_real/$subdir)
		$meson_configure build
		cd build
		ninja -v install
		cd ..
	else
		local make_configure=$make
		make_configure+=$'\t'CC=" $CXX" # original is gcc
		local lua_cflags=" -g -x c++"$CFLAGS
		if [[ $BSH_HOST_PLATFORM == darwin ]]; then
			lua_cflags+=" -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
		fi
		if [[ $BSH_DEBUG_RELEASE == release ]]; then
			lua_cflags+=" -O2"
		fi
		lua_cflags+=' -Wall $(MYCFLAGS)'
		make_configure+=$'\t'CFLAGS=$lua_cflags
		if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-mingw ]]; then
			make_configure+=$'\t'mingw
		else
			make_configure+=$'\t'posix
		fi
		make_configure+=$'\t'-j$NPROC
		VERBOSE=1 $make_configure
		mkdir $zip_root_real/$subdir
		VERBOSE=1 $make INSTALL_TOP=\'$(export_path $zip_root_real/$subdir)\' install
	fi
}

function compile_lua52() {
	get_and_cd lua-5.2.4.tar.gz lua52_version
	echo aaa571c445bdafe72c7e116bda8f2a415e8dcb05d988e4072e6dc15029c32fae src/lua.h | sha256sum -c
	compile_lua5x lua5.2
	sed -n 425,444p src/lua.h > $zip_root_real/licenses/lua5.2.LICENSE
	uncd_and_unget
	library_versions+="lua52_version = '$lua52_version-tpt-libs'"$'\n'
}

function compile_lua51() {
	get_and_cd lua-5.1.5.tar.gz lua51_version
	echo 470551c185f058360f8d0f9e5c54a29a3950f78af6a93f3fe9e4039a380c7b87 src/lua.h | sha256sum -c
	compile_lua5x lua5.1
	sed -n 369,388p src/lua.h > $zip_root_real/licenses/lua5.1.LICENSE
	uncd_and_unget
	library_versions+="lua51_version = '$lua51_version-tpt-libs'"$'\n'
}

function compile_luajit() {
	if [[ $BSH_HOST_PLATFORM == emscripten ]]; then
		return
	fi
	get_and_cd LuaJIT-2.1.0-git.tar.gz luajit_version
	mkdir $zip_root_real/luajit
	mkdir $zip_root_real/luajit/include
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		cd src
		local msvcbuild_configure=./msvcbuild.bat
		msvcbuild_configure+=$'\t'debug
		inplace_sed 's|cl /nologo|cl /nologo /DLUAJIT_ENABLE_LUA52COMPAT|g' msvcbuild.bat
		inplace_sed 's|/O2|/O2 /MD|g' msvcbuild.bat # make sure we have an /MD to replace; dynamic, release
		if [[ $BSH_STATIC_DYNAMIC == static ]]; then
			msvcbuild_configure+=$'\t'static
			inplace_sed 's|/O2 /MD|/O2 /MT|g' msvcbuild.bat # static, release
			inplace_sed 's|/Zi|/Z7|g' msvcbuild.bat # include debugging info in the .lib
		fi
		if [[ $BSH_DEBUG_RELEASE != release ]]; then
			inplace_sed 's|/MT|/MTd|g' msvcbuild.bat # static, debug
			inplace_sed 's|/MD|/MDd|g' msvcbuild.bat # dynamic, debug
		fi
		if [[ $BSH_HOST_ARCH == x86_64 ]]; then
			msvcbuild_configure+=$'\t'gc64
		fi
		$msvcbuild_configure
		mkdir $zip_root_real/luajit/lib
		cp lua51.lib $zip_root_real/luajit/lib
		if [[ $BSH_STATIC_DYNAMIC != static ]]; then
			mkdir $zip_root_real/luajit/bin
			cp lua51.dll $zip_root_real/luajit/bin
			cp lua51.pdb $zip_root_real/luajit/lib
		fi
		cd ..
	else
		local make_configure=$make
		make_configure+=$'\t'Q=
		if [[ $BSH_HOST_PLATFORM == windows ]]; then
			make_configure+=$'\t'TARGET_SYS=Windows
			if [[ $BSH_HOST_LIBC == mingw ]]; then
				make_configure+=$'\t'CC=$CC
			fi
		fi
		if [[ $BSH_HOST_PLATFORM == darwin ]]; then
			make_configure+=$'\t'TARGET_SYS=Darwin
			make_configure+=$'\t'CC=$CC
			make_configure+=$'\t'HOST_CC=clang
		fi
		if [[ $BSH_HOST_PLATFORM == android ]]; then
			make_configure+=$'\t'TARGET_SYS=Linux
			make_configure+=$'\t'CC="clang -fPIC"
			make_configure+=$'\t'CROSS=$android_toolchain_dir/bin/$android_toolchain_prefix$android_system_version-
			make_configure+=$'\t'TARGET_AR="$AR rcus"
			case $BSH_HOST_ARCH in
			x86_64)  make_configure+=$'\t'HOST_CC="gcc"     ;;
			x86)     make_configure+=$'\t'HOST_CC="gcc -m32";;
			aarch64) make_configure+=$'\t'HOST_CC="gcc"     ;;
			arm)     make_configure+=$'\t'HOST_CC="gcc -m32";;
			esac
		fi
		if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC-$BSH_STATIC_DYNAMIC == windows-mingw-static ]]; then
			patch_breakpoint $patches_real/luajit-mingw-force-static.patch apply
		fi
		if [[ $BSH_HOST_ARCH-$BSH_HOST_PLATFORM == x86-android ]] || [[ $BSH_HOST_ARCH-$BSH_HOST_PLATFORM == arm-android ]]; then
			patch_breakpoint $patches_real/luajit-android-32b-ftell.patch apply
		fi
		make_configure+=$'\t'CCDEBUG=" -g"
		make_configure+=$'\t'LUAJIT_A=" liblua.a"
		if [[ $BSH_DEBUG_RELEASE != release ]]; then
			make_configure+=$'\t'CCOPT=" -fomit-frame-pointer" # original has -O2
		fi
		local XCFLAGS=" -DLUAJIT_ENABLE_LUA52COMPAT"
		if [[ $BSH_HOST_ARCH == x86_64 ]]; then
			XCFLAGS+=" -DLUAJIT_ENABLE_GC64"
		fi
		make_configure+=$'\t'XCFLAGS=$XCFLAGS
		make_configure+=$'\t'-j$NPROC
		cd src
		VERBOSE=1 $make_configure
		mkdir $zip_root_real/luajit/lib
		cp liblua.a $zip_root_real/luajit/lib
		cd ..
	fi
	cp src/lauxlib.h $zip_root_real/luajit/include
	cp src/lua.h $zip_root_real/luajit/include
	cp src/luaconf.h $zip_root_real/luajit/include
	cp src/lualib.h $zip_root_real/luajit/include
	echo 4e546dc0556ca5f1514ae9d9bad723501a51da556342590b7076fb42f2930f25 COPYRIGHT | sha256sum -c
	cp COPYRIGHT $zip_root_real/licenses/luajit.LICENSE
	uncd_and_unget
	library_versions+="luajit_version = '$luajit_version-tpt-libs'"$'\n'
}

function compile_fftw() {
	get_and_cd fftw-3.3.8.tar.gz fftw_version
	mkdir build
	cmake_configure=cmake # not local because add_*_flags can't deal with that
	cmake_configure+=$'\t'-G$'\t'Ninja
	cmake_configure+=$'\t'-DCMAKE_BUILD_TYPE=$cmake_build_type
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		cmake_configure+=$'\t'-DCMAKE_VS_PLATFORM_TOOLSET=$cmake_vs_toolset
	fi
	add_install_flags cmake_configure
	cmake_configure+=$'\t'-DDISABLE_FORTRAN=ON
	cmake_configure+=$'\t'-DENABLE_FLOAT=ON
	case $BSH_HOST_ARCH in
	x86_64)
		;&
	x86)
		cmake_configure+=$'\t'-DENABLE_SSE=ON
		cmake_configure+=$'\t'-DENABLE_SSE2=ON
		;;
	esac
	if [[ $BSH_STATIC_DYNAMIC == static ]]; then
		cmake_configure+=$'\t'-DBUILD_SHARED_LIBS=OFF
	fi
	if [[ $BSH_HOST_PLATFORM == android ]]; then
		add_android_flags cmake_configure
	fi
	if [[ $BSH_HOST_PLATFORM == emscripten ]]; then
		add_emscripten_flags cmake_configure
	fi
	cd build
	VERBOSE=1 $cmake_configure ..
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC-$BSH_STATIC_DYNAMIC == windows-msvc-static ]]; then
		windows_msvc_static_mt
	fi
	if [[ $BSH_HOST_PLATFORM == emscripten ]]; then
		inplace_sed 's|CMAKE_C_FLAGS:STRING=|CMAKE_C_FLAGS:STRING='$EMCC_CFLAGS' |g' CMakeCache.txt
	fi
	inplace_sed 's|HAVE_ALLOCA:INTERNAL=1|HAVE_ALLOCA:INTERNAL=0|g' CMakeCache.txt
	inplace_sed 's|CMAKE_C_FLAGS:STRING=|CMAKE_C_FLAGS:STRING=-DWITH_OUR_MALLOC |g' CMakeCache.txt
	VERBOSE=1 cmake --build . -j$NPROC --config $cmake_build_type
	VERBOSE=1 cmake --install . --config $cmake_build_type
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		cp **/fftw3f.pdb $zip_root_real/lib
	fi
	cd ..
	echo 231f7edcc7352d7734a96eef0b8030f77982678c516876fcb81e25b32d68564c COPYING | sha256sum -c
	cp COPYING $zip_root_real/licenses/fftw3f.LICENSE
	uncd_and_unget
	library_versions+="fftw_version = '$fftw_version-tpt-libs'"$'\n'
}

function compile_jsoncpp() {
	get_and_cd jsoncpp-1.9.5.tar.gz jsoncpp_version
	mkdir build
	cmake_configure=cmake # not local because add_*_flags can't deal with that
	cmake_configure+=$'\t'-G$'\t'Ninja
	cmake_configure+=$'\t'-DCMAKE_BUILD_TYPE=$cmake_build_type
	cmake_configure+=$'\t'-DJSONCPP_WITH_TESTS=OFF
	cmake_configure+=$'\t'-DJSONCPP_WITH_POST_BUILD_UNITTEST=OFF
	cmake_configure+=$'\t'-DJSONCPP_WITH_PKGCONFIG_SUPPORT=OFF
	cmake_configure+=$'\t'-DJSONCPP_WITH_CMAKE_PACKAGE=OFF
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		cmake_configure+=$'\t'-DCMAKE_VS_PLATFORM_TOOLSET=$cmake_vs_toolset
	fi
	add_install_flags cmake_configure
	if [[ $BSH_STATIC_DYNAMIC == static ]]; then
		cmake_configure+=$'\t'-DBUILD_SHARED_LIBS=OFF
		cmake_configure+=$'\t'-DBUILD_STATIC_LIBS=ON
	else
		cmake_configure+=$'\t'-DBUILD_SHARED_LIBS=ON
		cmake_configure+=$'\t'-DBUILD_STATIC_LIBS=OFF
	fi
	cmake_configure+=$'\t'-DBUILD_OBJECT_LIBS=OFF
	if [[ $BSH_HOST_PLATFORM == android ]]; then
		add_android_flags cmake_configure
	fi
	if [[ $BSH_HOST_PLATFORM == emscripten ]]; then
		add_emscripten_flags cmake_configure
	fi
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC-$BSH_STATIC_DYNAMIC == windows-msvc-static ]]; then
		cmake_configure+=$'\t'-DJSONCPP_STATIC_WINDOWS_RUNTIME=ON
	fi
	cd build
	VERBOSE=1 $cmake_configure ..
	if [[ $BSH_HOST_PLATFORM == emscripten ]]; then
		inplace_sed 's|CMAKE_C_FLAGS:STRING=|CMAKE_C_FLAGS:STRING='$EMCC_CFLAGS' |g' CMakeCache.txt
		inplace_sed 's|CMAKE_CXX_FLAGS:STRING=|CMAKE_CXX_FLAGS:STRING='$EMCC_CXXFLAGS' |g' CMakeCache.txt
	fi
	VERBOSE=1 cmake --build . -j$NPROC --config $cmake_build_type
	VERBOSE=1 cmake --install . --config $cmake_build_type
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		cp **/jsoncpp*.pdb $zip_root_real/lib
	fi
	cd ..
	echo cec0db5f6d7ed6b3a72647bd50aed02e13c3377fd44382b96dc2915534c042ad LICENSE | sha256sum -c
	cp LICENSE $zip_root_real/licenses/jsoncpp.LICENSE
	uncd_and_unget
	library_versions+="jsoncpp_version = '$jsoncpp_version-tpt-libs'"$'\n'
}

function compile_nghttp2() {
	if [[ $BSH_HOST_PLATFORM == emscripten ]]; then
		return
	fi
	get_and_cd nghttp2-1.50.0.tar.gz nghttp2_version
	mkdir build
	cmake_configure=cmake # not local because add_*_flags can't deal with that
	cmake_configure+=$'\t'-G$'\t'Ninja
	cmake_configure+=$'\t'-DCMAKE_BUILD_TYPE=$cmake_build_type
	cmake_configure+=$'\t'-DENABLE_EXAMPLES=OFF
	cmake_configure+=$'\t'-DENABLE_FAILMALLOC=OFF
	cmake_configure+=$'\t'-DCMAKE_DISABLE_FIND_PACKAGE_OpenSSL=ON
	cmake_configure+=$'\t'-DCMAKE_DISABLE_FIND_PACKAGE_Libev=ON
	cmake_configure+=$'\t'-DCMAKE_DISABLE_FIND_PACKAGE_Libcares=ON
	cmake_configure+=$'\t'-DCMAKE_DISABLE_FIND_PACKAGE_ZLIB=ON
	cmake_configure+=$'\t'-DCMAKE_DISABLE_FIND_PACKAGE_Libngtcp2=ON
	cmake_configure+=$'\t'-DCMAKE_DISABLE_FIND_PACKAGE_Libngtcp2_crypto_openssl=ON
	cmake_configure+=$'\t'-DCMAKE_DISABLE_FIND_PACKAGE_PythonInterp=ON
	cmake_configure+=$'\t'-DCMAKE_DISABLE_FIND_PACKAGE_Libnghttp3=ON
	cmake_configure+=$'\t'-DCMAKE_DISABLE_FIND_PACKAGE_Libbpf=ON
	cmake_configure+=$'\t'-DCMAKE_DISABLE_FIND_PACKAGE_Systemd=ON
	cmake_configure+=$'\t'-DCMAKE_DISABLE_FIND_PACKAGE_Jansson=ON
	cmake_configure+=$'\t'-DCMAKE_DISABLE_FIND_PACKAGE_Libevent=ON
	cmake_configure+=$'\t'-DCMAKE_DISABLE_FIND_PACKAGE_Cython=ON
	cmake_configure+=$'\t'-DCMAKE_DISABLE_FIND_PACKAGE_PythonLibs=ON
	cmake_configure+=$'\t'-DCMAKE_DISABLE_FIND_PACKAGE_LibXml2=ON
	cmake_configure+=$'\t'-DCMAKE_DISABLE_FIND_PACKAGE_Jemalloc=ON
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		cmake_configure+=$'\t'-DCMAKE_VS_PLATFORM_TOOLSET=$cmake_vs_toolset
	fi
	add_install_flags cmake_configure
	if [[ $BSH_STATIC_DYNAMIC == static ]]; then
		cmake_configure+=$'\t'-DENABLE_STATIC_LIB=ON
		cmake_configure+=$'\t'-DENABLE_SHARED_LIB=OFF
	else
		cmake_configure+=$'\t'-DENABLE_STATIC_LIB=OFF
		cmake_configure+=$'\t'-DENABLE_SHARED_LIB=ON
	fi
	if [[ $BSH_HOST_PLATFORM == android ]]; then
		add_android_flags cmake_configure
	fi
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC-$BSH_STATIC_DYNAMIC == windows-msvc-static ]]; then
		cmake_configure+=$'\t'-DENABLE_STATIC_CRT=ON
	fi
	cd build
	VERBOSE=1 $cmake_configure ..
	VERBOSE=1 cmake --build . -j$NPROC --config $cmake_build_type
	VERBOSE=1 cmake --install . --config $cmake_build_type
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		cp **/nghttp2*.pdb $zip_root_real/lib
	fi
	cd ..
	echo 6b94f3abc1aabd0c72a7c7d92a77f79dda7c8a0cb3df839a97890b4116a2de2a COPYING | sha256sum -c
	cp COPYING $zip_root_real/licenses/nghttp2.LICENSE
	uncd_and_unget
}

function compile_bzip2() {
	if [[ $BSH_HOST_PLATFORM == emscripten ]]; then
		return
	fi
	get_and_cd bzip2-1.0.8.tar.gz bzip2_version
	dos2unix libbz2.def
	patch_breakpoint $patches_real/bzip2-meson.patch apply
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		patch_breakpoint $patches_real/bzip2-msvc-libname.patch apply
	fi
	local meson_configure=meson$'\t'setup
	if [[ $BSH_DEBUG_RELEASE == release ]]; then
		meson_configure+=$'\t'-Dbuildtype=debugoptimized
	else
		meson_configure+=$'\t'-Dbuildtype=debug
	fi
	if [[ $BSH_STATIC_DYNAMIC == static ]]; then
		if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
			meson_configure+=$'\t'-Db_vscrt=static_from_buildtype
			meson_configure+=$'\t'-Dc_args="['/Z7']" # include debug info in the .lib
		fi
		meson_configure+=$'\t'-Ddefault_library=static
	fi
	meson_configure+=$meson_cross_configure
	meson_configure+=$meson_dirs_configure
	meson_configure+=$'\t'--prefix$'\t'$(export_path $zip_root_real)
	$meson_configure build
	cd build
	ninja -v install
	cd ..
	echo c6dbbf828498be844a89eaa3b84adbab3199e342eb5cb2ed2f0d4ba7ec0f38a3 LICENSE | sha256sum -c
	cp LICENSE $zip_root_real/licenses/bzip2.LICENSE
	uncd_and_unget
	library_versions+="bzip2_version = '$bzip2_version-tpt-libs'"$'\n'
}

function compile() {
	local what=$1 # $2 and up hold names of libraries that have to be compiled before $what
	declare -n status=status_$what
	if [[ ${status:-} == compiling ]]; then
		>&2 echo "recursive dependency"
		exit 1
	fi
	if [[ ${status:-} == compiled ]]; then
		return
	fi
	shift
	while ! [[ -z "${1:-}" ]]; do
		dependency=$1
		compile $dependency
		shift
	done
	status=compiling
	eval "compile_$what"
	status=compiled
}

compile nghttp2
compile bzip2
compile jsoncpp
compile mbedtls
compile zlib
compile curl zlib mbedtls nghttp2
compile libpng zlib
compile sdl2
compile fftw
compile lua51
compile lua52
compile luajit

cat - << MESON > $temp_dir/$zip_root/meson.build
project('tpt-libs-prebuilt', 'cpp', version: '$BSH_VTAG')

host_arch = '$BSH_HOST_ARCH'
host_platform = '$BSH_HOST_PLATFORM'
host_libc = '$BSH_HOST_LIBC'
static_dynamic = '$BSH_STATIC_DYNAMIC'
debug_release = '$BSH_DEBUG_RELEASE'

$library_versions
MESON
if [[ $BSH_HOST_PLATFORM == android ]]; then
	cat - << MESON >> $temp_dir/$zip_root/meson.build
android_platform = '$android_platform'
android_toolchain_prefix = '$android_toolchain_prefix'
android_system_version = '$android_system_version'
android_arch_abi = '$android_arch_abi'

MESON
fi
cat $temp_dir/$zip_root/meson.template.build >> $temp_dir/$zip_root/meson.build
rm $temp_dir/$zip_root/meson.template.build

cd $temp_dir/$zip_root

set +e
shopt -s nullglob
for junk in \
	{.,./lua5.1,./lua5.2}/{bin/*.exe,bin/*-config,bin/{lua,luac},man,cmake,share,lib/lua} \
	junk.* \
	include/*.{f,f03} \
	include/libpng16 \
	include/nghttp2 \
	lib/{cmake,libpng,pkgconfig} \
; do
	rm -r $junk
done
if [[ $BSH_HOST_PLATFORM == windows ]]; then
	case $BSH_HOST_LIBC-$BSH_STATIC_DYNAMIC in
	msvc-static) rm \
		lib/libz*dll* \
		bin/zlib$debug_d.dll \
		lib/zlib$debug_d.lib \
		lib/zlib$debug_d.pdb;;
	msvc-dynamic) rm \
		lib/png-fix-itxt.pdb \
		lib/pngfix.pdb \
		lib/pngimage.pdb \
		lib/pngstest.pdb \
		lib/pngtest.pdb \
		lib/pngunknown.pdb \
		lib/pngvalid.pdb \
		lib/png_static.pdb \
		lib/libpng16_static$debug_d.lib \
		lib/zlibstatic$debug_d.lib \
		lib/zlibstatic.pdb;;
	mingw-static) rm \
		lib/libz*dll* \
		lib/libpng.dll.a \
		lib/libpng.a \
		bin/libzlib.dll;;
	esac
elif [[ $BSH_HOST_PLATFORM == darwin ]]; then
	for junk in lib/libz*dylib*; do rm -r $junk; done
else
	for junk in lib/libz*so* lib/libpng.a; do rm -r $junk; done
fi

find . -type d -empty -delete
shopt -u nullglob
set -e

cd ..
7z a -bb3 $zip_out $zip_root
