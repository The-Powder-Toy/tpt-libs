#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

temp_base=temp

. common.sh

if [ -z "${VTAG-}" ]; then
	>&2 echo "VTAG not set (see .github/workflows/build.yaml)"
	exit 1
fi

if [ -z "${build_sh_init-}" ]; then
	if [ -d $temp_base ]; then
		rm -r $temp_base
	fi
	mkdir $temp_base

	if [ $PLATFORM_SHORT == "win" ]; then
		for i in C:/Program\ Files\ \(x86\)/Microsoft\ Visual\ Studio/**/**/VC/Auxiliary/Build/vcvarsall.bat; do
			vcvarsall_path=$i
		done
		if [ $MACHINE_SHORT == "x86_64" ]; then
			x64_x86=x64
		else
			x64_x86=x86
		fi
		cat << BUILD_INIT_BAT > $temp_base/build_init.bat
@echo off
call "${vcvarsall_path}" ${x64_x86}
bash -c 'build_sh_init=1 ./build.sh'
BUILD_INIT_BAT
		./$temp_base/build_init.bat
	else
		build_sh_init=1 ./build.sh
	fi
	exit 0
fi

includes_root=include
libs_root=lib

BSHCFLAGS=
BSHLDFLAGS=
if [ $PLATFORM_SHORT == "mac" ]; then
	BSHCFLAGS=-mmacosx-version-min=10.9
	BSHLDFLAGS=-mmacosx-version-min=10.9
fi

make=$'make\t-j'
if [ -z "${NPROC-}" ]; then
	NPROC=`nproc`
fi
make="$make$NPROC"
includes=../../../$temp_base/$zip_root/$includes_root
libs=../../../$temp_base/$zip_root/$libs_root

fix_makefile_shells() {
	# because obviously it's more important to check if memcpy exists than to quote the shell properly
	for i in `find . -name Makefile`; do
		sed -i -s "s/\$(SHELL)/\"\$(SHELL)\"/" $i
	done
}

compile_zlib() {
	get_and_cd zlib-1.2.11.tar.gz # acquired from https://zlib.net/zlib-1.2.11.tar.gz
	if [ $PLATFORM_SHORT == "win" ]; then
		if [ $TOOLSET_SHORT == "msvc" ]; then
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
			make -f win32/Makefile.gcc libz.a
			cp libz.a $libs
		fi
	else
		CFLAGS=$BSHCFLAGS LDFLAGS=$BSHLDFLAGS ./configure --static
		$make
		cp libz.a $libs
	fi
	cp zconf.h zlib.h $includes
	uncd_and_unget
}

compile_fftw() {
	get_and_cd fftw-3.3.8.tar.gz # acquired from http://www.fftw.org/fftw-3.3.8.tar.gz (eww http)
	if [ $PLATFORM_SHORT == "win" ]; then
		if [ $TOOLSET_SHORT == "msvc" ]; then
			mkdir build
			cd build
			if [ $STATIC_DYNAMIC == "static" ]; then
				dynstat_options="-DBUILD_SHARED_LIBS=off"
			else
				dynstat_options=
			fi
			if [ $MACHINE_SHORT == "x86_64" ]; then
				x64_x86=$'-A\tx64'
			else
				x64_x86=$'-A\tWin32'
			fi
			cmake $x64_x86 $dynstat_options -DDISABLE_FORTRAN=on -DENABLE_FLOAT=on -DENABLE_SSE=on -DENABLE_SSE2=on ..
			cmake --build . --config Release
			cd ..
			cp build/Release/fftw3f.lib $libs
			if [ $STATIC_DYNAMIC == "dynamic" ]; then
				cp build/Release/fftw3f.dll $libs
			fi
		else
			build_for=x86_64-pc-mingw64
			./configure \
				--build=$build_for \
				--disable-shared \
				--enable-static \
				--enable-portable-binary \
				--disable-alloca \
				--with-our-malloc16 \
				--disable-threads \
				--disable-fortran \
				--enable-float \
				--enable-sse
			$make
			cp .libs/libfftw3f.a $libs
		fi
	else
		build_for=`./config.guess`
		CFLAGS=$BSHCFLAGS LDFLAGS=$BSHLDFLAGS ./configure \
			--build=$build_for \
			--disable-shared \
			--enable-static \
			--enable-portable-binary \
			--disable-alloca \
			--with-our-malloc16 \
			--disable-threads \
			--disable-fortran \
			--enable-float \
			--enable-sse
		$make
		cp .libs/libfftw3f.a $libs
	fi
	cp api/fftw3.h $includes
	uncd_and_unget
}

compile_lua51() {
	get_and_cd lua-5.1.5.tar.gz # acquired from https://www.lua.org/ftp/lua-5.1.5.tar.gz
	if [ $PLATFORM_SHORT == "win" ]; then
		if [ $TOOLSET_SHORT == "msvc" ]; then
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
			$make PLAT=mingw LUA_A="liblua5.1.a" mingw
			cp src/liblua5.1.a $libs
		fi
	else
		if [ $PLATFORM_SHORT == "lin" ]; then
			lua_plat=linux
		fi
		if [ $PLATFORM_SHORT == "mac" ]; then
			lua_plat=macosx
		fi
		$make MYCFLAGS=$BSHCFLAGS MYLDFLAGS=$BSHLDFLAGS PLAT=$lua_plat LUA_A="liblua5.1.a" $lua_plat
		cp src/liblua5.1.a $libs
	fi
	mkdir $includes/lua5.1
	cp src/lauxlib.h src/lua.h src/luaconf.h src/lualib.h $includes/lua5.1
	uncd_and_unget
}

compile_lua52() {
	get_and_cd lua-5.2.4.tar.gz # acquired from https://www.lua.org/ftp/lua-5.2.4.tar.gz
	if [ $PLATFORM_SHORT == "win" ]; then
		if [ $TOOLSET_SHORT == "msvc" ]; then
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
			$make PLAT=mingw LUA_A="liblua5.2.a" mingw
			cp src/liblua5.2.a $libs
		fi
	else
		if [ $PLATFORM_SHORT == "lin" ]; then
			lua_plat=linux
		fi
		if [ $PLATFORM_SHORT == "mac" ]; then
			lua_plat=macosx
		fi
		$make MYCFLAGS=$BSHCFLAGS MYLDFLAGS=$BSHLDFLAGS PLAT=$lua_plat LUA_A="liblua5.2.a" $lua_plat
		cp src/liblua5.2.a $libs
	fi
	mkdir $includes/lua5.2
	cp src/lauxlib.h src/lua.h src/luaconf.h src/lualib.h $includes/lua5.2
	uncd_and_unget
}

compile_luajit() {
	get_and_cd LuaJIT-2.1.0-beta3.tar.gz # acquired from https://luajit.org/download/LuaJIT-2.1.0-beta3.tar.gz
	if [ $PLATFORM_SHORT == "win" ]; then
		if [ $TOOLSET_SHORT == "msvc" ]; then
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
			cd src
			TARGET_SYS=Windows $make
			cd ..
			cp src/libluajit.a $libs
		fi
	else
		luajit_plat=
		if [ $PLATFORM_SHORT == "mac" ]; then
			luajit_plat=MACOSX_DEPLOYMENT_TARGET=10.9
		fi
		$make CFLAGS=$BSHCFLAGS LDFLAGS=$BSHLDFLAGS $luajit_plat LUAJIT_SO=
		cp src/libluajit.a $libs
	fi
	mkdir $includes/luajit-2.1
	cp src/lauxlib.h src/lua.h src/luaconf.h src/lualib.h src/luajit.h $includes/luajit-2.1
	uncd_and_unget
}

compile_curl() {
	get_and_cd curl-7.68.0.tar.gz # acquired from https://curl.haxx.se/download/curl-7.68.0.tar.gz
	if [ $PLATFORM_SHORT == "win" ]; then
		if [ $TOOLSET_SHORT == "msvc" ]; then
			cd winbuild
			if [ $STATIC_DYNAMIC == "static" ]; then
				dynstat_options=$'mode=static\tRTLIBCFG=static'
			else
				dynstat_options="mode=dll"
			fi
			if [ $MACHINE_SHORT == "x86_64" ]; then
				x64_x86=x64
			else
				x64_x86=x86
			fi
			nmake -f Makefile.vc $dynstat_options ENABLE_IDN=no DEBUG=no MACHINE=$x64_x86
			cd ..
			if [ $STATIC_DYNAMIC == "static" ]; then
				cp builds/libcurl-vc-$x64_x86-release-static-ipv6-sspi-winssl/lib/libcurl_a.lib $libs/curl.lib
			else
				cp builds/libcurl-vc-$x64_x86-release-dll-ipv6-sspi-winssl/lib/libcurl.lib $libs/curl.lib
				cp builds/libcurl-vc-$x64_x86-release-dll-ipv6-sspi-winssl/bin/libcurl.dll $libs
			fi
		else
			curl_plat=
			if [ $PLATFORM_SHORT == "mac" ]; then
				curl_plat=--with-darwinssl
			fi
			./configure $curl_plat \
				--enable-http \
				--enable-ipv6 \
				--enable-proxy \
				--disable-dict \
				--disable-file \
				--disable-ftp \
				--disable-gopher \
				--disable-imap \
				--disable-ldap \
				--disable-pop3 \
				--disable-rtsp \
				--disable-shared \
				--disable-smb \
				--disable-smtp \
				--disable-sspi \
				--disable-telnet \
				--disable-tftp \
				--without-brotli \
				--without-libidn2 \
				--without-librtmp \
				--without-nghttp2 \
				--without-nghttp3 \
				--without-ngtcp2 \
				--without-quiche \
				--without-winidn
			fix_makefile_shells
			$make
			cp lib/.libs/libcurl.a $libs
		fi
	else
		curl_plat=
		if [ $PLATFORM_SHORT == "mac" ]; then
			curl_plat=--with-darwinssl
		fi
		CFLAGS=$BSHCFLAGS LDFLAGS=$BSHLDFLAGS ./configure $curl_plat \
			--enable-http \
			--enable-ipv6 \
			--enable-proxy \
			--disable-dict \
			--disable-file \
			--disable-ftp \
			--disable-gopher \
			--disable-imap \
			--disable-ldap \
			--disable-pop3 \
			--disable-rtsp \
			--disable-shared \
			--disable-smb \
			--disable-smtp \
			--disable-sspi \
			--disable-telnet \
			--disable-tftp \
			--without-brotli \
			--without-libidn2 \
			--without-librtmp \
			--without-nghttp2 \
			--without-nghttp3 \
			--without-ngtcp2 \
			--without-quiche \
			--without-winidn
		$make
		cp lib/.libs/libcurl.a $libs
	fi
	mkdir $includes/curl
	cp include/curl/*.h $includes/curl
	uncd_and_unget
}

compile_sdl2() {
	get_and_cd SDL2-2.0.10.tar.gz # acquired from https://www.libsdl.org/release/SDL2-2.0.10.tar.gz
	if [ $PLATFORM_SHORT == "win" ]; then
		if [ $TOOLSET_SHORT == "msvc" ]; then
			mkdir build
			cd build
			if [ $STATIC_DYNAMIC == "static" ]; then
				dynstat_options=$'-DFORCE_STATIC_VCRT=ON\t-DBUILD_SHARED_LIBS=OFF\t-DLIBC=ON'
			else
				dynstat_options=
			fi
			if [ $MACHINE_SHORT == "x86_64" ]; then
				x64_x86=$'-A\tx64'
			else
				x64_x86=$'-A\tWin32'
			fi
			cmake $x64_x86 $dynstat_options \
				-DSDL_AUDIO=OFF \
				-DSDL_HAPTIC=OFF \
				-DSDL_JOYSTICK=OFF \
				-DSDL_POWER=OFF \
				-DHIDAPI=OFF \
				..
			cmake --build . --config Release
			cd ..
			cp build/Release/SDL2.lib $libs
			if [ $STATIC_DYNAMIC == "dynamic" ]; then
				cp build/Release/SDL2.dll $libs
			fi
		else
			build_for=$MACHINE_SHORT-pc-mingw32
			./configure \
				--build=$build_for \
				--disable-shared \
				--disable-audio \
				--disable-haptic \
				--disable-joystick \
				--disable-power \
				--disable-hidapi
			fix_makefile_shells
			$make
			cp build/.libs/libSDL2.a $libs
		fi
	else
		build_for=`./build-scripts/config.guess`
		CFLAGS=$BSHCFLAGS LDFLAGS=$BSHLDFLAGS ./configure \
			--build=$build_for \
			--disable-shared \
			--disable-audio \
			--disable-haptic \
			--disable-joystick \
			--disable-power \
			--disable-hidapi
		$make
		cp build/.libs/libSDL2.a $libs
	fi
	mkdir $includes/SDL2
	cp include/*.h $includes/SDL2
	uncd_and_unget
}

cp -r zip_stub/$quad $temp_base/$zip_root
mkdir -p $temp_base/$zip_root/$includes_root
mkdir -p $temp_base/$zip_root/$libs_root

compile_zlib
compile_curl
compile_sdl2
compile_fftw
compile_luajit
compile_lua51
compile_lua52

cd $temp_base
mv $zip_root $zip_root-$VTAG
7z a ../$zip_out $zip_root-$VTAG
