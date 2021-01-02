#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

temp_base=patchtemp
patchinfo=.patchinfo

case ${1-show} in
start)
	. common.sh

	if [ -d $temp_base ]; then
		>&2 echo "a patch is currently in progress"
		exit 1
	fi

	if [ -z ${2-} ]; then
		>&2 echo "need a tarball"
		exit 1
	fi
	patchtool_tarball=`basename $2`

	mkdir $temp_base

	skip_patch=yes
	get_and_cd $patchtool_tarball
	cd ../../..
	lib_path_common=$temp_base/lib
	lib_path_before=$temp_base/lib.before
	lib_path_after=$temp_base/lib.after
	mv $lib_path_common $lib_path_before
	skip_patch=
	get_and_cd $patchtool_tarball
	cd ../../..
	mv $lib_path_common $lib_path_after

	patch_path=patches/$platform-$dynstat/$patchtool_tarball.patch

	echo "lib_path_common=$lib_path_common" >> $temp_base/$patchinfo
	echo "lib_path_before=$lib_path_before" >> $temp_base/$patchinfo
	echo "lib_path_after=$lib_path_after"   >> $temp_base/$patchinfo
	echo "patch_path=$patch_path"           >> $temp_base/$patchinfo
	echo "PLATFORM_SHORT=$PLATFORM_SHORT"   >> $temp_base/$patchinfo
	echo "STATIC_DYNAMIC=$STATIC_DYNAMIC"   >> $temp_base/$patchinfo
	;;

info)
	if ! [ -d $temp_base ]; then
		>&2 echo "no patch is currently in progress"
		exit 1
	fi
	cat $temp_base/$patchinfo
	;;

show)
	if ! [ -d $temp_base ]; then
		>&2 echo "no patch is currently in progress (try $0 help)"
		exit 1
	fi
	. $temp_base/$patchinfo

	. common.sh

	set +e
	diff -Naur $lib_path_before/* $lib_path_after/*
	diffcode=$?
	set -e
	[ $diffcode = 0 ] || [ $diffcode = 1 ]
	;;

write)
	if ! [ -d $temp_base ]; then
		>&2 echo "no patch is currently in progress"
		exit 1
	fi
	. $temp_base/$patchinfo

	. common.sh

	set +e
	diff -Naur $lib_path_before/* $lib_path_after/* > .diff
	diffcode=$?
	set -e
	[ $diffcode = 0 ] || [ $diffcode = 1 ]
	rm $patch_path
	mv .diff $patch_path
	if [ $diffcode = 1 ]; then
		>&2 echo "written diff to $patch_path"
	else
		rm $patch_path
		>&2 echo "diff empty, removed $patch_path"
	fi
	;;

finish)
	if ! [ -d $temp_base ]; then
		>&2 echo "no patch is currently in progress"
		exit 1
	fi
	rm -r $temp_base
	;;

*)
	>&2 cat << HELP
Usage: $0 help
  or:  $0 start TARBALL
  or:  $0 info
  or:  $0 show
  or:  $0 write
  or:  $0 finish

Explanation of the verbs above:
  - help: Show this help.
  - start TARBALL: Start a patch session with TARBALL (pick one from tarballs/). This will apply the diff in the corresponding patch file, if one exists.
  - info: If a patch session is in progress, show settings.
  - show: If a patch session is in progress, show the diff.
  - write: If a patch session is in progress, Write the diff back to (or remove, in case of an empty diff) the corresponding patch file, which is version-controlled.
  - finish: Finish patch session if one is in progress and clean up temporary files.

The verb 'show' is assumed if none is supplied.
HELP
	exit 1
esac
