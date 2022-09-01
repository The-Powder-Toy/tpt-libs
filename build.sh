#!/usr/bin/env bash

set -euo pipefail
shopt -s globstar
IFS=$'\n\t'

# TODO: check if libs have debug info
# TODO: check if release libs are optimized
# TODO: check if static libs are static
# TODO: check if only necessary files are packaged
# TODO: check if windows libs use the same crt as the exe
# TODO: check if exes can be run from build sites
# TODO: check if luas are c++-aware
# TODO: check if libcurl uses zlib

. ./common.sh

tarball_hash() {
	local tarball_name=$1
	case $tarball_name in
	zlib-1.2.11.tar.gz)        sha256sum=c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1;;
	fftw-3.3.8.tar.gz)         sha256sum=6113262f6e92c5bd474f2875fa1b01054c4ad5040f6b0da7c03c98821d9ae303;;
	lua-5.1.5.tar.gz)          sha256sum=2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333;;
	lua-5.2.4.tar.gz)          sha256sum=b9e2e4aad6789b3b63a056d442f7b39f0ecfca3ae0f1fc0ae4e9614401b69f4b;;
	LuaJIT-2.1.0-beta3.tar.gz) sha256sum=1ad2e34b111c802f9d0cdf019e986909123237a28c746b21295b63c9e785d9c3;;
	curl-7.68.0.tar.gz)        sha256sum=1dd7604e418b0b9a9077f62f763f6684c1b092a7bc17e3f354b8ad5c964d7358;;
	SDL2-2.0.20.tar.gz)        sha256sum=c56aba1d7b5b0e7e999e4a7698c70b63a3394ff9704b5f6e1c57e0c16f04dd06;;
	libpng-1.6.37.tar.gz)      sha256sum=daeb2620d829575513e35fecc83f0d3791a620b9b93d800b763542ece9390fb4;;
	*)                                         >&2 echo "no such tarball (update tarball_hash)" && exit 1;;
	esac
}

get_and_cd() {
	local tarball_name=$1
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
x86_64-windows-mingw-static) ;;
x86_64-windows-mingw-dynamic) ;;
x86_64-windows-msvc-static) ;;
x86_64-windows-msvc-dynamic) ;;
x86-windows-msvc-static) ;;
x86-windows-msvc-dynamic) ;;
x86_64-darwin-macos-static) ;;
aarch64-darwin-macos-static) ;;
x86-android-bionic-static) ;;
x86_64-android-bionic-static) ;;
arm-android-bionic-static) ;;
aarch64-android-bionic-static) ;;
*) >&2 echo "configuration $BSH_HOST_ARCH-$BSH_HOST_PLATFORM-$BSH_HOST_LIBC-$BSH_STATIC_DYNAMIC is not supported" && exit 1;;
esac

android_platform=none
if [[ $BSH_HOST_PLATFORM == android ]]; then
	android_platform=android-30
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

if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
	case $BSH_HOST_ARCH in
	x86_64) vs_env_arch=x64;;
	x86)    vs_env_arch=x86;;
	esac
	. ./vs-env.sh $vs_env_arch
elif [[ $BSH_HOST_PLATFORM == darwin ]]; then
	# may need export SDKROOT=$(xcrun --show-sdk-path --sdk macosx11.1)
	CC=clang
	CXX=clang++
	if [[ $BSH_HOST_ARCH == aarch64 ]]; then
		export MACOSX_DEPLOYMENT_TARGET=11.0
		CC+=" -arch arm64"
		CXX+=" -arch arm64"
	else
		export MACOSX_DEPLOYMENT_TARGET=10.9
		CC+=" -arch x86_64"
		CXX+=" -arch x86_64"
	fi
	export CC
	export CXX
elif [[ $BSH_HOST_PLATFORM == android ]]; then
	case $BSH_HOST_ARCH in
	x86_64)  android_toolchain_prefix=x86_64-linux-android    ; android_system_version=21; android_arch_abi=x86_64     ;;
	x86)     android_toolchain_prefix=i686-linux-android      ; android_system_version=19; android_arch_abi=x86        ;;
	aarch64) android_toolchain_prefix=aarch64-linux-android   ; android_system_version=21; android_arch_abi=arm64-v8a  ;;
	arm)     android_toolchain_prefix=armv7a-linux-androideabi; android_system_version=19; android_arch_abi=armeabi-v7a;;
	esac
	android_toolchain_dir=$ANDROID_NDK_LATEST_HOME/toolchains/llvm/prebuilt/linux-x86_64
	CC=$android_toolchain_dir/bin/$android_toolchain_prefix$android_system_version-clang
	CXX=$android_toolchain_dir/bin/$android_toolchain_prefix$android_system_version-clang++
	LD=$android_toolchain_dir/bin/$android_toolchain_prefix-ld
	AR=$android_toolchain_dir/bin/llvm-ar
	echo $AR
	CC+=" -fPIC"
	CXX+=" -fPIC"
	LD+=" -fPIC"
	export CC
	export CXX
	export LD
	export AR
else
	export CC=gcc
	export CXX=g++
fi
CFLAGS=
if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC != windows-msvc ]]; then
	CFLAGS+=" -ffunction-sections -fdata-sections"
fi
export CFLAGS

function check_program() {
	local program_name=$1
	which $program_name > /dev/null || (>&2 echo "can't find $program_name or similar" && exit 1)
}

make=make
if [[ $BSH_BUILD_PLATFORM == windows ]]; then
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
cat - << MESON > $temp_dir/$zip_root/meson.build
project('tpt-libs-prebuilt', [ 'c' ])

host_arch = '$BSH_HOST_ARCH'
host_platform = '$BSH_HOST_PLATFORM'
host_libc = '$BSH_HOST_LIBC'
static_dynamic = '$BSH_STATIC_DYNAMIC'
debug_release = '$BSH_DEBUG_RELEASE'

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
zip_root_real=$(realpath $temp_dir/$zip_root)

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

function export_path() {
	local path=$1
	if [[ $BSH_BUILD_PLATFORM == windows ]]; then
		cygpath -m $path
	else
		echo $path
	fi
}

function good_sed() {
	local subst=$1
	local path=$2
	if [[ $BSH_BUILD_PLATFORM == darwin ]]; then
		sed -i "" -e $subst $path
	else
		sed -i $subst $path
	fi
}

function add_android_flags() {
	declare -n cmake_configure=$1
	cmake_configure+=$'\t'-DANDROID_ABI=$android_arch_abi
	cmake_configure+=$'\t'-DANDROID_PLATFORM=android-$android_system_version
	cmake_configure+=$'\t'-DCMAKE_TOOLCHAIN_FILE=$(export_path $ANDROID_NDK_LATEST_HOME/build/cmake/android.toolchain.cmake)
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
		if ! patch -p1 -i $patch_path; then
			patch --binary -p1 -i $patch_path # windows :D
		fi
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
		diff -Naur $dir_name.old $dir_name.new > $patch_path
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

function windows_msvc_static_mt() {
	good_sed 's|/MD|/MT|g' CMakeCache.txt # static msvcrt
}

function compile_zlib() {
	get_and_cd zlib-1.2.11.tar.gz # acquired from https://zlib.net/zlib-1.2.11.tar.gz
	mkdir build
	local cmake_configure=cmake
	cmake_configure+=$'\t'-G$'\t'Ninja
	cmake_configure+=$'\t'-DCMAKE_BUILD_TYPE=$cmake_build_type
	cmake_configure+=$'\t'-DCMAKE_INSTALL_PREFIX=$(export_path $zip_root_real)
	cd build
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
}

function compile_libpng() {
	get_and_cd libpng-1.6.37.tar.gz # acquired from https://download.sourceforge.net/libpng/libpng-1.6.37.tar.gz
	mkdir build
	cmake_configure=cmake # not local because add_android_flags can't deal with that
	cmake_configure+=$'\t'-G$'\t'Ninja
	cmake_configure+=$'\t'-DCMAKE_BUILD_TYPE=$cmake_build_type
	cmake_configure+=$'\t'-DCMAKE_INSTALL_PREFIX=$(export_path $zip_root_real)
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
		mingw-dynamic) zlib_path=$zip_root_real/lib/libzlib.dll.a;;
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
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC-$BSH_STATIC_DYNAMIC == windows-mingw-dynamic ]]; then
		good_sed 's|CMAKE_C_FLAGS:STRING=|CMAKE_C_FLAGS:STRING=-fno-asynchronous-unwind-tables |g' CMakeCache.txt
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
}

function compile_curl() {
	if [[ $BSH_HOST_PLATFORM == android ]]; then
		return
	fi
	get_and_cd curl-7.68.0.tar.gz # acquired from https://curl.haxx.se/download/curl-7.68.0.tar.gz
	mkdir build
	local cmake_configure=cmake
	cmake_configure+=$'\t'-G$'\t'Ninja
	cmake_configure+=$'\t'-DBUILD_TESTING=OFF
	cmake_configure+=$'\t'-DCMAKE_BUILD_TYPE=$cmake_build_type
	cmake_configure+=$'\t'-DCMAKE_INSTALL_PREFIX=$(export_path $zip_root_real)
	cmake_configure+=$'\t'-DCMAKE_USE_LIBSSH2=OFF
	cmake_configure+=$'\t'-DBUILD_CURL_EXE=OFF
	cmake_configure+=$'\t'-DHTTP_ONLY=ON
	if [[ $BSH_HOST_PLATFORM == windows ]]; then
		patch_breakpoint $patches_real/libcurl-windows-tls-socket.patch apply
		cmake_configure+=$'\t'-DCMAKE_USE_WINSSL=ON
		cmake_configure+=$'\t'-DCURL_CA_PATH=none
	fi
	if [[ $BSH_HOST_PLATFORM == darwin ]]; then
		cmake_configure+=$'\t'-DCMAKE_USE_SECTRANSP=ON
		cmake_configure+=$'\t'-DCURL_CA_PATH=none
	fi
	cmake_configure+=$'\t'-DCMAKE_PREFIX_PATH=$(export_path $zip_root_real)
	if [[ $BSH_STATIC_DYNAMIC == static ]]; then
		cmake_configure+=$'\t'-DBUILD_SHARED_LIBS=OFF
	fi
	cd build
	VERBOSE=1 $cmake_configure ..
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC-$BSH_STATIC_DYNAMIC == windows-msvc-static ]]; then
		windows_msvc_static_mt
	fi
	VERBOSE=1 cmake --build . -j$NPROC --config $cmake_build_type
	VERBOSE=1 cmake --install . --config $cmake_build_type
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		cp **/libcurl*.pdb $zip_root_real/lib
	fi
	cd ..
	echo db3c4a3b3695a0f317a0c5176acd2f656d18abc45b3ee78e50935a78eb1e132e COPYING | sha256sum -c
	cp COPYING $zip_root_real/licenses/libcurl.LICENSE
	uncd_and_unget
}

function compile_sdl2() {
	get_and_cd SDL2-2.0.20.tar.gz # acquired from https://www.libsdl.org/release/SDL2-2.0.20.tar.gz
	patch_breakpoint $patches_real/sdl-no-dynapi.patch apply
	patch_breakpoint $patches_real/sdl-fix-haptic-inclusion.patch apply
	mkdir build
	cmake_configure=cmake # not local because add_android_flags can't deal with that
	cmake_configure+=$'\t'-G$'\t'Ninja
	cmake_configure+=$'\t'-DCMAKE_BUILD_TYPE=$cmake_build_type
	cmake_configure+=$'\t'-DCMAKE_INSTALL_PREFIX=$(export_path $zip_root_real)
	cmake_configure+=$'\t'-DSDL_AUDIO=OFF
	cmake_configure+=$'\t'-DSDL_POWER=OFF
	cmake_configure+=$'\t'-DSDL_LIBC=ON
	if [[ $BSH_HOST_PLATFORM == android ]]; then
		patch_breakpoint $patches_real/sdl-android-no-bad-warnings.patch apply
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
	echo VERBOSE=1 $cmake_configure ..
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
			-classpath $ANDROID_SDK_ROOT/platforms/$android_platform/android.jar \
			$(find . -name "*.java")
		$JAVA_HOME_8_X64/bin/jar cMf sdl.jar $(find . -name "*.class")
		cp sdl.jar $zip_root_real/lib
		cd ../../../../..
	fi
	echo fcb07e07ac6bc8b2fcf047b50431ef4ebe5b619d7ca7c82212018309a9067426 LICENSE.txt | sha256sum -c
	cp LICENSE.txt $zip_root_real/licenses/sdl2.LICENSE
	uncd_and_unget
}

function compile_lua5x() {
	local subdir=$1
	patch_breakpoint $patches_real/$subdir-extern-c.patch apply
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		find . -name "*.c" -exec sh -c 'x="{}"; mv "$x" "${x}pp"' \; # compile as C++ despite .c extension
		patch_breakpoint $patches_real/$subdir-windows-msvc-meson.patch apply
		local meson_configure=meson
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
		VERBOSE=1 $make INSTALL_TOP=$(export_path $zip_root_real/$subdir) install
		if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC-$BSH_STATIC_DYNAMIC == windows-mingw-dynamic ]]; then
			cp src/*.dll $zip_root_real/$subdir/bin
		fi
	fi
}

function compile_lua52() {
	get_and_cd lua-5.2.4.tar.gz # acquired from https://www.lua.org/ftp/lua-5.2.4.tar.gz
	compile_lua5x lua5.2
	echo 60302176c6c1f18d2d0aa3dc8f89ba1ed4c83bd24b79cc84542fbaefd04741cf src/lua.h | sha256sum -c
	sed -n 425,444p src/lua.h > $zip_root_real/licenses/lua5.2.LICENSE
	uncd_and_unget
}

function compile_lua51() {
	get_and_cd lua-5.1.5.tar.gz # acquired from https://www.lua.org/ftp/lua-5.1.5.tar.gz
	compile_lua5x lua5.1
	echo d293b0c707a42c251a97127a72471c4310f3290517e77717fc1e7365ecf54584 src/lua.h | sha256sum -c
	sed -n 369,388p src/lua.h > $zip_root_real/licenses/lua5.1.LICENSE
	uncd_and_unget
}

function compile_luajit() {
	get_and_cd LuaJIT-2.1.0-beta3.tar.gz # acquired from https://luajit.org/download/LuaJIT-2.1.0-beta3.tar.gz
	mkdir $zip_root_real/luajit
	mkdir $zip_root_real/luajit/include
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		cd src
		local msvcbuild_configure=./msvcbuild.bat
		msvcbuild_configure+=$'\t'debug
		good_sed 's|/O2|/O2 /MD|g' msvcbuild.bat # make sure we have an /MD to replace; dynamic, release
		if [[ $BSH_STATIC_DYNAMIC == static ]]; then
			msvcbuild_configure+=$'\t'static
			good_sed 's|/O2 /MD|/O2 /MT|g' msvcbuild.bat # static, release
			good_sed 's|/Zi|/Z7|g' msvcbuild.bat # include debugging info in the .lib
		fi
		if [[ $BSH_DEBUG_RELEASE != release ]]; then
			good_sed 's|/MT|/MTd|g' msvcbuild.bat # static, debug
			good_sed 's|/MD|/MDd|g' msvcbuild.bat # dynamic, debug
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
		make_configure+=$'\t'CCDEBUG=" -g"
		make_configure+=$'\t'LUAJIT_A=" liblua.a"
		if [[ $BSH_DEBUG_RELEASE != release ]]; then
			make_configure+=$'\t'CCOPT=" -fomit-frame-pointer" # original has -O2
		fi
		make_configure+=$'\t'-j$NPROC
		cd src
		VERBOSE=1 $make_configure
		if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-mingw ]]; then
			if [[ $BSH_STATIC_DYNAMIC == static ]]; then
				mkdir $zip_root_real/luajit/lib
				cp liblua.a $zip_root_real/luajit/lib
			else
				mkdir $zip_root_real/luajit/bin
				cp lua51.dll $zip_root_real/luajit/bin
			fi
		else
			mkdir $zip_root_real/luajit/lib
			cp liblua.a $zip_root_real/luajit/lib
		fi
		cd ..
	fi
	cp src/lauxlib.h $zip_root_real/luajit/include
	cp src/lua.h $zip_root_real/luajit/include
	cp src/luaconf.h $zip_root_real/luajit/include
	cp src/lualib.h $zip_root_real/luajit/include
	echo accb335aa3102f80d31caa2c2508fbcb795314106493519a367f13a87d0e87de COPYRIGHT | sha256sum -c
	cp COPYRIGHT $zip_root_real/licenses/luajit.LICENSE
	uncd_and_unget
}

function compile_fftw() {
	get_and_cd fftw-3.3.8.tar.gz # acquired from http://www.fftw.org/fftw-3.3.8.tar.gz (eww http)
	mkdir build
	cmake_configure=cmake # not local because add_android_flags can't deal with that
	cmake_configure+=$'\t'-G$'\t'Ninja
	cmake_configure+=$'\t'-DCMAKE_BUILD_TYPE=$cmake_build_type
	cmake_configure+=$'\t'-DCMAKE_INSTALL_PREFIX=$(export_path $zip_root_real)
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
	cd build
	VERBOSE=1 $cmake_configure ..
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC-$BSH_STATIC_DYNAMIC == windows-msvc-static ]]; then
		windows_msvc_static_mt
	fi
	good_sed 's|HAVE_ALLOCA:INTERNAL=1|HAVE_ALLOCA:INTERNAL=0|g' CMakeCache.txt
	good_sed 's|CMAKE_C_FLAGS:STRING=|CMAKE_C_FLAGS:STRING=-DWITH_OUR_MALLOC |g' CMakeCache.txt
	VERBOSE=1 cmake --build . -j$NPROC --config $cmake_build_type
	VERBOSE=1 cmake --install . --config $cmake_build_type
	if [[ $BSH_HOST_PLATFORM-$BSH_HOST_LIBC == windows-msvc ]]; then
		cp **/fftw3f.pdb $zip_root_real/lib
	fi
	cd ..
	echo 231f7edcc7352d7734a96eef0b8030f77982678c516876fcb81e25b32d68564c COPYING | sha256sum -c
	cp COPYING $zip_root_real/licenses/fftw3f.LICENSE
	uncd_and_unget
}

compile_zlib # must precede compile_curl and compile_libpng
compile_libpng
compile_curl
compile_sdl2
compile_fftw
compile_lua51
compile_lua52
compile_luajit

cd $temp_dir/$zip_root

case $BSH_HOST_ARCH-$BSH_HOST_PLATFORM-$BSH_HOST_LIBC-$BSH_STATIC_DYNAMIC in
x86-android-bionic-static)
	;&
x86_64-android-bionic-static)
	;&
arm-android-bionic-static)
	;&
aarch64-android-bionic-static)
	rm -r bin/*-config
	rm -r include/*.{f,f03}
	rm -r include/libpng16
	rm -r lib/cmake
	rm -r lib/libpng # cmake files
	rm -r lib/libpng.a
	rm -r lib/libz*.so
	rm -r lib/pkgconfig
	rm -r lua{5.1,5.2}/bin
	rm -r lua{5.1,5.2}/man
	rm -r share
	;;

x86_64-darwin-macos-static)
	;&
aarch64-darwin-macos-static)
	rm -r bin/*-config
	rm -r include/*.{f,f03}
	rm -r include/libpng16
	rm -r lib/cmake
	rm -r lib/libpng # cmake files
	rm -r lib/libpng.a
	rm -r lib/libz*.dylib
	rm -r lib/pkgconfig
	rm -r lua{5.1,5.2}/bin
	rm -r lua{5.1,5.2}/man
	rm -r share
	;;

x86_64-windows-mingw-static)
	;&
x86_64-windows-mingw-dynamic)
	rm -r include/*.{f,f03}
	rm -r include/libpng16
	rm -r lib/cmake
	rm -r lib/libpng # cmake files
	rm -r lib/libpng.a
	rm -r lib/pkgconfig
	rm -r lua{5.1,5.2}/lib/lua # empty
	rm -r lua{5.1,5.2}/man
	rm -r share
	if [[ $BSH_STATIC_DYNAMIC == static ]]; then
		rm -r bin
		rm -r lua{5.1,5.2}/bin
		rm -r lib/libzlib.dll.a
	else
		rm -r bin/*-config
		rm -r lib/libcurl$debug_hd"_imp".lib
		rm -r lib/libfftw3f.dll.a
		rm -r lib/libpng16$debug_d.a
		rm -r lib/libpng16$debug_d.dll.a
		rm -r lib/libSDL2$debug_d.dll.a
		rm -r lib/libzlib.dll.a
		rm -r lua{5.1,5.2}/bin/*.exe
		rm -r lua{5.1,5.2}/lib
		rm -r bin/png-fix-itxt.exe
		rm -r bin/pngfix.exe
		rm -r lib/libpng.dll.a
		rm -r lib/libzlibstatic.a
	fi
	;;

x86_64-linux-gnu-static)
	rm -r bin
	rm -r include/*.{f,f03}
	rm -r lib/cmake
	rm -r lib/libpng # cmake files
	rm -r lib/libpng.a # symlink to libpng16.a
	rm -r lib/libz.so*
	rm -r lib/pkgconfig
	rm -r lua{5.1,5.2}/bin
	rm -r lua{5.1,5.2}/lib/lua # empty
	rm -r lua{5.1,5.2}/man
	rm -r lua{5.1,5.2}/share
	rm -r share
	;;

x86-windows-msvc-static)
	;&
x86-windows-msvc-dynamic)
	;&
x86_64-windows-msvc-static)
	;&
x86_64-windows-msvc-dynamic)
	rm -r cmake
	rm -r include/*.{f,f03}
	rm -r lib/cmake
	rm -r lib/libpng # cmake files
	rm -r lib/pkgconfig
	rm -r share
	if [[ $BSH_STATIC_DYNAMIC == static ]]; then
		rm -r bin
		rm -r lib/zlib$debug_d.pdb
		rm -r lib/zlib$debug_d.lib
	else
		rm -r bin/*.exe
		rm -r bin/*-config
		rm -r lib/libpng16_static$debug_d.lib
		rm -r lib/png-fix-itxt.pdb
		rm -r lib/pngfix.pdb
		rm -r lib/pngimage.pdb
		rm -r lib/pngstest.pdb
		rm -r lib/pngtest.pdb
		rm -r lib/pngunknown.pdb
		rm -r lib/pngvalid.pdb
		rm -r lib/png_static.pdb
		rm -r lib/zlibstatic.pdb
		rm -r lib/zlibstatic$debug_d.lib
	fi
	;;
esac

cd ..
7z a -bb3 $zip_out $zip_root
