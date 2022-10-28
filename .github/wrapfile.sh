#!/usr/bin/env bash

set -euo pipefail
shopt -s globstar
IFS=$'\n\t'

. ./.github/common.sh

cd $temp_dir

zip_sha256sum=$(sha256sum $zip_out)
zip_sha256sum=${zip_sha256sum:0:64}

cat << WRAP > $wrap_out
[wrap-file]
directory = $zip_root

source_url = $ASSET_URL
source_filename = $zip_root.zip
source_hash = $zip_sha256sum
WRAP
