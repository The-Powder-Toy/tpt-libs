#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

if [ -z "${PLATFORM_SHORT-}" ]; then
	>&2 echo "PLATFORM_SHORT not set" 
	exit 1
fi
if [ -z "${STATIC_DYNAMIC-}" ]; then
	>&2 echo "STATIC_DYNAMIC not set" 
	exit 1
fi

temp_base=temp

if [ -z "${build_sh_init-}" ]; then
	if [ -d $temp_base ]; then
		rm -r $temp_base
	fi
	mkdir $temp_base

	if [ $PLATFORM_SHORT == "win" ]; then
		for i in C:/Program\ Files\ \(x86\)/Microsoft\ Visual\ Studio/**/**/VC/Auxiliary/Build/vcvarsall.bat; do
			vcvarsall_path=$i
		done
		cat << BUILD_INIT_BAT > $temp_base/build_init.bat
@echo off
call "${vcvarsall_path}" x64
bash -c 'build_sh_init=1 ./build.sh'
BUILD_INIT_BAT
		./$temp_base/build_init.bat
	else
		build_sh_init=1 ./build.sh
	fi
	exit 0
fi

platform=${PLATFORM_SHORT}64
dynstat=${STATIC_DYNAMIC}
zip_root=tpt-libs-prebuilt-$platform-$dynstat
zip_out=$temp_base/libraries.zip
includes_root=include
libs_root=$dynstat-$platform

make=$'make\t-j2'
includes=../../../$temp_base/$zip_root/$includes_root
libs=../../../$temp_base/$zip_root/$libs_root

get_and_cd() {
	mkdir $temp_base/lib
	cd $temp_base/lib
	tarball=../../tarballs/$1
	patch=../../patches/$platform-$dynstat/$1.patch
	# note that the sha256 sums in this script are only for checking integrity
	# (i.e. forcing the script to break in a predictable way if something
	# changes upstream), not for cryptographic verification; there is of course
	# no reason to validate the tarballs if they come right from the repo, but
	# it is useful if you choose to not trust those and download ones yourself
	echo $2 $tarball | sha256sum -c
	tar xzf $tarball
	if [ -f $patch ]; then
		patch -p0 -i $patch
	fi
	cd *
}

uncd_and_unget() {
	cd ../../..
	rm -r $temp_base/lib
}

compile_zlib() {
	# acquired from https://zlib.net/zlib-1.2.11.tar.gz
	get_and_cd zlib-1.2.11.tar.gz c3e5e9fdd5004dcb542feda5ee4f0ff0744628baf8ed2dd5d66f8ca1197cb1a1
	if [ $PLATFORM_SHORT == "win" ]; then
		if [ $STATIC_DYNAMIC == "static" ]; then
			dynstat_target=zlib.lib
		else
			dynstat_target=zlib1.dll
		fi
		nmake -f win32/Makefile.msc $dynstat_target
		if [ $STATIC_DYNAMIC == "static" ]; then
			cp zlib.lib $libs/z.lib
		else
			cp zdll.lib $libs/z.lib
			cp zlib1.dll $libs
		fi
	else
		./configure --static
		$make
		cp libz.a $libs
	fi
	cp zconf.h zlib.h $includes
	uncd_and_unget
}

compile_fftw() {
	# acquired from http://www.fftw.org/fftw-3.3.8.tar.gz (eww http)
	get_and_cd fftw-3.3.8.tar.gz 6113262f6e92c5bd474f2875fa1b01054c4ad5040f6b0da7c03c98821d9ae303
	if [ $PLATFORM_SHORT == "win" ]; then
		mkdir build
		cd build
		if [ $STATIC_DYNAMIC == "static" ]; then
			dynstat_options="-DBUILD_SHARED_LIBS=off"
		else
			dynstat_options=
		fi
		cmake -A x64 $dynstat_options -DDISABLE_FORTRAN=on -DENABLE_FLOAT=on -DENABLE_SSE=on -DENABLE_SSE2=on ..
		cmake --build . --config Release
		cd ..
		cp build/Release/fftw3f.lib $libs
		if [ $STATIC_DYNAMIC == "dynamic" ]; then
			cp build/Release/fftw3f.dll $libs
		fi
	else
		./configure \
			--build=`./config.guess` \
			--disable-shared \
			--enable-static \
			--disable-alloca \
			--with-our-malloc16 \
			--disable-threads \
			--disable-fortran \
			--enable-portable-binary \
			--enable-float \
			--enable-sse
		$make
		cp .libs/libfftw3f.a $libs
	fi
	cp api/fftw3.h $includes
	uncd_and_unget
}

compile_lua51() {
	# acquired from https://www.lua.org/ftp/lua-5.1.5.tar.gz
	get_and_cd lua-5.1.5.tar.gz 2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333
	if [ $PLATFORM_SHORT == "win" ]; then
		if [ $STATIC_DYNAMIC == "static" ]; then
			dynstat_options="-Db_vscrt=mt"
		else
			dynstat_options=
		fi
		meson -Dbuildtype=release $dynstat_options build
		cd build
		ninja
		cd ..
		if [ $STATIC_DYNAMIC == "static" ]; then
			cp build/liblua5.1.a $libs/lua5.1.lib
		else
			cp build/lua5.1.lib $libs/lua5.1.lib
			cp build/lua5.1.dll $libs
		fi
	else
		if [ $PLATFORM_SHORT == "lin" ]; then
			lua_plat=linux
		fi
		if [ $PLATFORM_SHORT == "mac" ]; then
			lua_plat=macosx
		fi
		$make PLAT=$lua_plat LUA_A="liblua5.1.a" $lua_plat
		cp src/liblua5.1.a $libs
	fi
	mkdir $includes/lua5.1
	cp src/lauxlib.h src/lua.h src/luaconf.h src/lualib.h $includes/lua5.1
	uncd_and_unget
}

compile_lua52() {
	# acquired from https://www.lua.org/ftp/lua-5.2.4.tar.gz
	get_and_cd lua-5.2.4.tar.gz b9e2e4aad6789b3b63a056d442f7b39f0ecfca3ae0f1fc0ae4e9614401b69f4b
	if [ $PLATFORM_SHORT == "win" ]; then
		if [ $STATIC_DYNAMIC == "static" ]; then
			dynstat_options="-Db_vscrt=mt"
		else
			dynstat_options=
		fi
		meson -Dbuildtype=release $dynstat_options build
		cd build
		ninja
		cd ..
		if [ $STATIC_DYNAMIC == "static" ]; then
			cp build/liblua5.2.a $libs/lua5.2.lib
		else
			cp build/lua5.2.lib $libs/lua5.2.lib
			cp build/lua5.2.dll $libs
		fi
	else
		if [ $PLATFORM_SHORT == "lin" ]; then
			lua_plat=linux
		fi
		if [ $PLATFORM_SHORT == "mac" ]; then
			lua_plat=macosx
		fi
		$make PLAT=$lua_plat LUA_A="liblua5.2.a" $lua_plat
		cp src/liblua5.2.a $libs
	fi
	mkdir $includes/lua5.2
	cp src/lauxlib.h src/lua.h src/luaconf.h src/lualib.h $includes/lua5.2
	uncd_and_unget
}

compile_luajit() {
	# acquired from https://luajit.org/download/LuaJIT-2.1.0-beta3.tar.gz
	get_and_cd LuaJIT-2.1.0-beta3.tar.gz 1ad2e34b111c802f9d0cdf019e986909123237a28c746b21295b63c9e785d9c3
	if [ $PLATFORM_SHORT == "win" ]; then
		cd src
		if [ $STATIC_DYNAMIC == "static" ]; then
			dynstat_options=static
		else
			dynstat_options=
		fi
		./msvcbuild.bat $dynstat_options
		cd ..
		cp src/luajit21.lib $libs
		if [ $STATIC_DYNAMIC == "dynamic" ]; then
			cp src/luajit21.dll $libs
		fi
	else
		luajit_plat=
		if [ $PLATFORM_SHORT == "mac" ]; then
			luajit_plat=MACOSX_DEPLOYMENT_TARGET=10.9
		fi
		$make $luajit_plat LUAJIT_SO=
		cp src/libluajit.a $libs
	fi
	mkdir $includes/luajit-2.1
	cp src/lauxlib.h src/lua.h src/luaconf.h src/lualib.h src/luajit.h $includes/luajit-2.1
	uncd_and_unget
}

compile_curl() {
	# acquired from https://curl.haxx.se/download/curl-7.68.0.tar.gz
	get_and_cd curl-7.68.0.tar.gz 1dd7604e418b0b9a9077f62f763f6684c1b092a7bc17e3f354b8ad5c964d7358
	if [ $PLATFORM_SHORT == "win" ]; then
		cd winbuild
		if [ $STATIC_DYNAMIC == "static" ]; then
			dynstat_options=$'mode=static\tRTLIBCFG=static'
		else
			dynstat_options="mode=dll"
		fi
		nmake -f Makefile.vc $dynstat_options ENABLE_IDN=no DEBUG=no MACHINE=x64
		cd ..
		if [ $STATIC_DYNAMIC == "static" ]; then
			cp builds/libcurl-vc-x64-release-static-ipv6-sspi-winssl/lib/libcurl_a.lib $libs/curl.lib
		else
			cp builds/libcurl-vc-x64-release-dll-ipv6-sspi-winssl/lib/libcurl.lib $libs/curl.lib
			cp builds/libcurl-vc-x64-release-dll-ipv6-sspi-winssl/bin/libcurl.dll $libs
		fi
	else
		curl_plat=
		if [ $PLATFORM_SHORT == "mac" ]; then
			curl_plat=--with-darwinssl
		fi
		./configure $curl_plat \
			--disable-shared \
			--disable-ftp \
			--disable-telnet \
			--disable-smtp \
			--disable-imap \
			--disable-pop3 \
			--disable-smb \
			--disable-gopher \
			--disable-dict \
			--disable-file \
			--disable-tftp \
			--disable-rtsp \
			--disable-ldap \
			--without-libidn2 \
			--without-librtmp \
			--without-brotli
		$make
		cp lib/.libs/libcurl.a $libs
	fi
	mkdir $includes/curl
	cp include/curl/*.h $includes/curl
	uncd_and_unget
}

compile_sdl2() {
	# acquired from https://www.libsdl.org/release/SDL2-2.0.10.tar.gz
	get_and_cd SDL2-2.0.10.tar.gz b4656c13a1f0d0023ae2f4a9cf08ec92fffb464e0f24238337784159b8b91d57
	if [ $PLATFORM_SHORT == "win" ]; then
		mkdir build
		cd build
		if [ $STATIC_DYNAMIC == "static" ]; then
			dynstat_options=$'-DFORCE_STATIC_VCRT=ON\t-DBUILD_SHARED_LIBS=OFF'
		else
			dynstat_options=
		fi
		cmake -A x64 $dynstat_options \
			-DSDL_AUDIO=OFF \
			-DSDL_HAPTIC=OFF \
			-DSDL_JOYSTICK=OFF \
			-DSDL_POWER=OFF \
			-DHIDAPI=OFF \
			..
		cmake --build . --config Release
		cd ..
		cp build/Release/SDL2.lib build/Release/SDL2main.lib $libs
		if [ $STATIC_DYNAMIC == "dynamic" ]; then
			cp build/Release/SDL2.dll $libs
		fi
	else
		./configure \
			--build=`build-scripts/config.guess` \
			--disable-shared \
			--disable-audio \
			--disable-haptic \
			--disable-joystick \
			--disable-power \
			--disable-hidapi
		$make
		cp build/.libs/libSDL2.a build/.libs/libSDL2main.a $libs
	fi
	mkdir $includes/SDL2
	cp include/*.h $includes/SDL2
	uncd_and_unget
}

cd $temp_base
7z x ../zip_stub/$platform-$dynstat.zip
mv $platform-$dynstat $zip_root
cd ..
mkdir -p $temp_base/$zip_root/$includes_root
mkdir -p $temp_base/$zip_root/$libs_root

compile_sdl2
compile_curl
compile_fftw
compile_zlib
compile_luajit
compile_lua51
compile_lua52

cd $temp_base
7z a ../$zip_out $zip_root
