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

	if [ $TOOLSET_SHORT == "msvc" ]; then
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

BSHCC=gcc
BSHCXX=g++
BSHCFLAGS=
BSHLDFLAGS=
if [ $PLATFORM_SHORT == "mac" ]; then
	BSHCC=clang
	BSHCXX=clang++
	BSHCFLAGS=-mmacosx-version-min=10.9
	BSHLDFLAGS=-mmacosx-version-min=10.9
	if [ $MACHINE_SHORT == "arm64" ]; then
		BSHCFLAGS=$'-arch\tarm64\t-mmacosx-version-min=10.15'
		BSHLDFLAGS=$'-arch\tarm64\t-mmacosx-version-min=10.15'
	fi
fi
export CFLAGS=$BSHCFLAGS
export LDFLAGS=$BSHLDFLAGS

makebin="make"
if [ $TOOLSET_SHORT == "mingw" ]; then
	makebin="mingw32-make"
fi
make="$makebin"
make+=$'\t-j'
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
		elif [ $TOOLSET_SHORT == "mingw" ]; then
			if [ $STATIC_DYNAMIC == "static" ]; then
				$make -f win32/Makefile.gcc libz.a
				cp libz.a $libs
			else
				$make -f win32/Makefile.gcc zlib1.dll
				cp zlib1.dll $libs
			fi
		fi
	else
		CC=$BSHCC CXX=$BSHCXX CFLAGS=$BSHCFLAGS LDFLAGS=$BSHLDFLAGS ./configure --static
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
		elif [ $TOOLSET_SHORT == "mingw" ]; then
			build_for=x86_64-pc-mingw32
			if [ $STATIC_DYNAMIC == "static" ]; then
				dynstat_options=$'--disable-shared\t--enable-static'
			else
				dynstat_options=$'--enable-shared\t--disable-static'
			fi
			./configure $dynstat_options \
				--build=$build_for \
				--enable-static \
				--disable-alloca \
				--with-our-malloc16 \
				--disable-threads \
				--disable-fortran \
				--enable-float \
				--enable-sse
			fix_makefile_shells
			mkdir bin
			cd bin
			ln -s `which $makebin` make
			cd ..
			PATH="`readlink -f bin`:$PATH" $make
			if [ $STATIC_DYNAMIC == "static" ]; then
				cp .libs/libfftw3f.a $libs
			else
				cp .libs/libfftw3f-3.dll $libs
			fi
		fi
	else
		fftw_plat=--build=`./config.guess`
		fftw_plat+=$'\t--enable-sse'
		if [ $PLATFORM_SHORT == "mac" ] && [ $MACHINE_SHORT == "arm64" ]; then
			fftw_plat=$'--build=x86_64-apple-darwin\t--host=aarch64-apple-darwin'
			fftw_plat+=$'\t--enable-neon'
		fi
		CC=$BSHCC CXX=$BSHCXX CFLAGS=$BSHCFLAGS LDFLAGS=$BSHLDFLAGS ./configure $fftw_plat \
			--disable-shared \
			--enable-static \
			--disable-alloca \
			--with-our-malloc16 \
			--disable-threads \
			--disable-fortran \
			--enable-float
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
		elif [ $TOOLSET_SHORT == "mingw" ]; then
			if [ $STATIC_DYNAMIC == "static" ]; then
				$make PLAT=mingw LUA_A="liblua5.1.a" mingw
				cp src/liblua5.1.a $libs
			else
				$make PLAT=mingw LUA_A="lua5.1.dll" mingw
				cp src/lua5.1.dll $libs
			fi
		fi
	else
		if [ $PLATFORM_SHORT == "lin" ]; then
			lua_plat=linux
		fi
		if [ $PLATFORM_SHORT == "mac" ]; then
			lua_plat=macosx
		fi
		$make CC=$BSHCXX CFLAGS="$BSHCFLAGS" MYLDFLAGS="$BSHLDFLAGS" PLAT=$lua_plat LUA_A="liblua5.1.a" $lua_plat
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
		elif [ $TOOLSET_SHORT == "mingw" ]; then
			if [ $STATIC_DYNAMIC == "static" ]; then
				$make PLAT=mingw LUA_A="liblua5.2.a" mingw
				cp src/liblua5.2.a $libs
			else
				$make PLAT=mingw LUA_A="lua5.2.dll" mingw
				cp src/lua5.2.dll $libs
			fi
		fi
	else
		if [ $PLATFORM_SHORT == "lin" ]; then
			lua_plat=linux
		fi
		if [ $PLATFORM_SHORT == "mac" ]; then
			lua_plat=macosx
		fi
		$make CC=$BSHCXX CFLAGS="$BSHCFLAGS" MYLDFLAGS="$BSHLDFLAGS" PLAT=$lua_plat LUA_A="liblua5.2.a" $lua_plat
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
		elif [ $TOOLSET_SHORT == "mingw" ]; then
			cd src
			TARGET_SYS=Windows $make
			cd ..
			if [ $STATIC_DYNAMIC == "static" ]; then
				cp src/libluajit.a $libs
			else
				cp src/luajit21.dll $libs
			fi
		fi
	else
		luajit_plat=
		if [ $PLATFORM_SHORT == "mac" ]; then
			luajit_plat=MACOSX_DEPLOYMENT_TARGET=10.9
			if [ $MACHINE_SHORT == "arm64" ]; then
				luajit_plat=MACOSX_DEPLOYMENT_TARGET=10.15
			fi
		fi
		CC=$BSHCC CXX=$BSHCXX CFLAGS= LDFLAGS= $make TARGET_CFLAGS="$BSHCFLAGS" TARGET_LDFLAGS="$BSHLDFLAGS" $luajit_plat LUAJIT_SO=
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
		elif [ $TOOLSET_SHORT == "mingw" ]; then
			build_for=$MACHINE_SHORT-pc-mingw32
			if [ $STATIC_DYNAMIC == "static" ]; then
				dynstat_options=$'--disable-shared\t--enable-static'
			else
				dynstat_options=$'--enable-shared\t--disable-static'
			fi
			# may or may not need --without-zlib -- LBPHacker
			./configure $dynstat_options \
				--build=$build_for \
				--disable-dependency-tracking \
				--enable-http \
				--enable-ipv6 \
				--enable-proxy \
				--with-schannel \
				--disable-dict \
				--disable-file \
				--disable-ftp \
				--disable-gopher \
				--disable-imap \
				--disable-ldap \
				--disable-pop3 \
				--disable-rtsp \
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
			mkdir bin
			cd bin
			ln -s `which $makebin` make
			cd ..
			PATH="`readlink -f bin`:$PATH" $make
			if [ $STATIC_DYNAMIC == "static" ]; then
				cp lib/.libs/libcurl.a $libs
			else
				cp lib/.libs/libcurl-4.dll $libs
			fi
		fi
	else
		curl_plat=
		if [ $PLATFORM_SHORT == "mac" ]; then
			curl_plat=--with-darwinssl
			if [ $MACHINE_SHORT == "arm64" ]; then
				curl_plat+=$'\t--host=aarch64-apple-darwin'
			fi
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
		elif [ $TOOLSET_SHORT == "mingw" ]; then
			build_for=$MACHINE_SHORT-pc-mingw32
			if [ $STATIC_DYNAMIC == "static" ]; then
				dynstat_options=$'--disable-shared'
			else
				dynstat_options=
			fi
			./configure $dynstat_options \
				--build=$build_for \
				--disable-audio \
				--disable-haptic \
				--disable-joystick \
				--disable-power \
				--disable-hidapi
			fix_makefile_shells
			$make
			if [ $STATIC_DYNAMIC == "static" ]; then
				cp build/.libs/libSDL2.a $libs
			else
				cp build/.libs/SDL2.dll $libs
			fi
		fi
	else
		sdl2_plat=--build=`./build-scripts/config.guess`
		if [ $PLATFORM_SHORT == "mac" ] && [ $MACHINE_SHORT == "arm64" ]; then
			sdl2_plat=$'--build=x86_64-apple-darwin\t--host=aarch64-apple-darwin'
		fi
		CFLAGS=$BSHCFLAGS LDFLAGS=$BSHLDFLAGS ./configure $sdl2_plat \
			--disable-shared \
			--disable-audio \
			--disable-haptic \
			--disable-joystick \
			--disable-power \
			--disable-hidapi
		$make
		cp build/.libs/libSDL2.a $libs
	fi
	cp include/*.h $includes
	uncd_and_unget
}

cp -r zip_stub/$quad $temp_base/$zip_root
mkdir -p $temp_base/$zip_root/$includes_root
mkdir -p $temp_base/$zip_root/$libs_root

jobsuffix=""
jobfinish=""
if [ $NPROC -ge 4 ]; then
	jobsuffix="&"
	jobfinish="wait"
fi
eval "compile_zlib $jobsuffix"
eval "compile_sdl2 $jobsuffix"
eval "compile_luajit $jobsuffix"
eval "compile_lua52 $jobsuffix"
eval "compile_lua51 $jobsuffix"
eval "compile_fftw $jobsuffix"
eval "compile_curl $jobsuffix"
eval "$jobfinish"

cd $temp_base
mv $zip_root $zip_root-$VTAG
7z a ../$zip_out $zip_root-$VTAG
