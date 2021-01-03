#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

temp_base=temp

. common.sh

if [ -z "${VTAG-}" ]; then
	>&2 echo "VTAG not set (see .github/workflows/build.yaml)"
	exit 1
fi
if [ -z "${ASSET-}" ]; then
	>&2 echo "ASSET not set (see .github/workflows/build.yaml)"
	exit 1
fi

zip_sha256sum=`sha256sum $zip_out`
zip_sha256sum=${zip_sha256sum:0:64}

cat << WRAP > $wrap_out
[wrap-file]
directory = $zip_root-$VTAG

source_url = $ASSET
source_filename = $zip_root-$VTAG.zip
source_hash = $zip_sha256sum
WRAP
