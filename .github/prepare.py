import datetime
import json
import os
import re
import sys

ref = os.getenv('GITHUB_REF')

match = re.match(r'refs/tags/(v[0-9]+)', ref)
if match:
	vtag = match.group(1)
else:
	vtag = datetime.datetime.now().strftime('v%Y%m%d%H%M%S')
print('::set-output name=vtag::' + vtag)

configurations = []
for bsh_host_arch, bsh_host_platform, bsh_host_libc, bsh_static_dynamic, bsh_build_platform,        runs_on in [
	(   'x86_64' ,           'linux',         'gnu',           'static',            'linux', 'ubuntu-18.04' ),
	(   'x86_64' ,         'windows',       'mingw',           'static',          'windows', 'windows-2019' ),
	(   'x86_64' ,         'windows',       'mingw',          'dynamic',          'windows', 'windows-2019' ),
	(   'x86_64' ,         'windows',        'msvc',           'static',          'windows', 'windows-2019' ),
	(   'x86_64' ,         'windows',        'msvc',          'dynamic',          'windows', 'windows-2019' ),
	(      'x86' ,         'windows',        'msvc',           'static',          'windows', 'windows-2019' ),
	(      'x86' ,         'windows',        'msvc',          'dynamic',          'windows', 'windows-2019' ),
	(   'x86_64' ,          'darwin',       'macos',           'static',           'darwin',   'macos-11.0' ),
	(  'aarch64' ,          'darwin',       'macos',           'static',           'darwin',   'macos-11.0' ),
	(      'x86' ,         'android',      'bionic',           'static',            'linux', 'ubuntu-18.04' ),
	(   'x86_64' ,         'android',      'bionic',           'static',            'linux', 'ubuntu-18.04' ),
	(      'arm' ,         'android',      'bionic',           'static',            'linux', 'ubuntu-18.04' ),
	(  'aarch64' ,         'android',      'bionic',           'static',            'linux', 'ubuntu-18.04' ),
]:
	for debug_release in [ 'debug', 'release' ]:
		configurations.append({
			'bsh_build_platform': bsh_build_platform,
			'bsh_host_arch': bsh_host_arch,
			'bsh_host_platform': bsh_host_platform,
			'bsh_host_libc': bsh_host_libc,
			'bsh_static_dynamic': bsh_static_dynamic,
			'bsh_debug_release': debug_release,
			'runs_on': runs_on,
			'asset_name': f'tpt-libs-prebuilt-{bsh_host_arch}-{bsh_host_platform}-{bsh_host_libc}-{bsh_static_dynamic}-{debug_release}-{vtag}',
		})

print('::set-output name=matrix::' + json.dumps({ 'include': configurations }))
print('::set-output name=do_release::' + (ref.startswith('refs/tags/v') and 'yes' or 'no'))
