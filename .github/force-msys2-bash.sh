set -euo pipefail
IFS=$'\t\n'

if [[ $BSH_HOST_ARCH == x86 ]]; then
	env=mingw32
	msystem=MINGW32
else
	env=ucrt64
	msystem=UCRT64
fi

echo 'C:\msys64\'"$env"'\bin' >> tmp
echo 'C:\msys64\usr\bin' >> tmp
cat $GITHUB_PATH >> tmp
mv tmp $GITHUB_PATH

echo "MSYSTEM=$msystem" >> $GITHUB_ENV
echo "PKG_CONFIG="'C:\msys64\'"$env"'\bin\pkg-config.exe' >> $GITHUB_ENV
