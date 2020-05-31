#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

zip_base=tpt-libs-prebuilt-lin64-static
source_url_base=https://trigraph.net/powdertoy/libraries/source

make=$'make\t-j2'
includes=../../$zip_base/include
libs=../../$zip_base/static-lin64

if [ -f $ZIP_OUT ]; then
	rm $ZIP_OUT
fi
if [ -d $zip_base ]; then
	rm -rf $zip_base
fi
if [ -d lib ]; then
	rm -rf lib
fi

get_and_cd() {
	mkdir lib
	cd lib
	wget -O lib.zip $source_url_base/$1
	echo $2 lib.zip | sha256sum -c
	7z x lib.zip
	rm lib.zip
	cd *
}

uncd_and_unget() {
	cd ../..
	rm -rf lib
}

compile_zlib() {
	get_and_cd zlib-1.2.11.zip 30c3742534dabb02a7cdd7ddbb7e1f9146607e47842de37b30a22ac1e50b7396
	./configure --static
	$make
	cp zconf.h zlib.h $includes
	cp libz.a $libs
	uncd_and_unget
}

compile_fftw() {
	get_and_cd fftw-3.3.8.zip 072e38bc11c3ad66c1f5336ae95be7577c1579513ebc2f309f46e21d6cfa2ab6
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
	cp api/fftw3.h $includes
	cp .libs/libfftw3f.a $libs
	uncd_and_unget
}

compile_lua51() {
	get_and_cd lua-5.1.5.zip 739b9f9b3e4430f27b2356b7cadf8303844dd2985ac67f7f500c4e489cc2a9d6
	$make PLAT=linux LUA_A="liblua5.1.a" linux
	mkdir $includes/lua5.1
	cp src/lauxlib.h src/lua.h src/luaconf.h src/lualib.h $includes/lua5.1
	cp src/liblua5.1.a $libs
	uncd_and_unget
}

compile_lua52() {
	get_and_cd lua-5.2.4.zip b8d007facfbb24218fe3945b923f43a819395cb28cc539cb2c5f6ba35ad42396
	$make PLAT=linux LUA_A="liblua5.2.a" linux
	mkdir $includes/lua5.2
	cp src/lauxlib.h src/lua.h src/luaconf.h src/lualib.h $includes/lua5.2
	cp src/liblua5.2.a $libs
	uncd_and_unget
}

compile_luajit() {
	get_and_cd LuaJIT-2.0.5.zip 851286d949bb1acfd3f419651cc9f6928e73fbf42429fe6eb5e75ba10283536b
	$make LUAJIT_SO=
	mkdir $includes/luajit-2.0
	cp src/lauxlib.h src/lua.h src/luaconf.h src/lualib.h src/luajit.h $includes/luajit-2.0
	cp src/libluajit.a $libs
	uncd_and_unget
}

compile_curl() {
	get_and_cd curl-7.68.0.zip 3a2f5ae5d5ab6472cc455b1d9587040096532d349e840bf7d2b31c9b8f42d6c5
	./configure \
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
		--without-libidn2
	$make
	mkdir $includes/curl
	cp include/curl/*.h $includes/curl
	cp lib/.libs/libcurl.a $libs
	uncd_and_unget
}

compile_sdl2() {
	get_and_cd SDL2-2.0.10.zip c6968be558b6bdfcdba2f2e7d08cbe2b3ec01a5db8b0e3e8067d7aa52028ee00
	./configure \
		--build=`build-scripts/config.guess` \
		--disable-shared \
		--disable-audio \
		--disable-video-wayland \
		--disable-video-opengl \
		--disable-video-opengles \
		--disable-video-vulkan \
		--disable-video-dummy
	$make
	mkdir $includes/SDL2
	cp include/*.h $includes/SDL2
	cp build/.libs/libSDL2.a build/.libs/libSDL2main.a $libs
	uncd_and_unget
}

mkdir $zip_base
mkdir $zip_base/include
mkdir $zip_base/static-lin64

compile_sdl2
compile_curl
compile_zlib
compile_fftw
compile_lua51
compile_lua52
compile_luajit

7z a $ZIP_OUT $zip_base
