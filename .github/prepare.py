import datetime
import json
import os
import re
import sys

ref = os.getenv('GITHUB_REF')

def set_output(key, value):
	with open(os.getenv('GITHUB_OUTPUT'), 'a') as f:
		f.write(f"{key}={value}\n")

match = re.match(r'refs/tags/(v[0-9]+)', ref)
if match:
	vtag = match.group(1)
else:
	vtag = datetime.datetime.now().strftime('v%Y%m%d%H%M%S')
set_output('vtag', vtag)

configurations = []
for bsh_host_arch, bsh_host_platform, bsh_host_libc, bsh_static_dynamic, bsh_build_platform,        runs_on in [
	(   'x86_64' ,           'linux',         'gnu',           'static',            'linux', 'ubuntu-20.04' ),
	(   'x86_64' ,         'windows',       'mingw',           'static',          'windows', 'windows-2019' ),
	(   'x86_64' ,         'windows',       'mingw',          'dynamic',          'windows', 'windows-2019' ),
	(   'x86_64' ,         'windows',        'msvc',           'static',          'windows', 'windows-2019' ),
	(   'x86_64' ,         'windows',        'msvc',          'dynamic',          'windows', 'windows-2019' ),
	(      'x86' ,         'windows',        'msvc',           'static',          'windows', 'windows-2019' ),
	(      'x86' ,         'windows',        'msvc',          'dynamic',          'windows', 'windows-2019' ),
	(   'x86_64' ,          'darwin',       'macos',           'static',           'darwin',     'macos-11' ),
	(  'aarch64' ,          'darwin',       'macos',           'static',           'darwin',     'macos-11' ),
	(      'x86' ,         'android',      'bionic',           'static',            'linux', 'ubuntu-20.04' ),
	(   'x86_64' ,         'android',      'bionic',           'static',            'linux', 'ubuntu-20.04' ),
	(      'arm' ,         'android',      'bionic',           'static',            'linux', 'ubuntu-20.04' ),
	(  'aarch64' ,         'android',      'bionic',           'static',            'linux', 'ubuntu-20.04' ),
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

set_output('matrix', json.dumps({ 'include': configurations }))
set_output('do_release', ref.startswith('refs/tags/v') and 'yes' or 'no')
