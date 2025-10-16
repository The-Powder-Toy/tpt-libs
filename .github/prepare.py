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
for bsh_host_arch, bsh_host_platform, bsh_host_libc, bsh_static_dynamic, bsh_build_platform,            runs_on in [
	(   'x86_64' ,           'linux',         'gnu',           'static',            'linux',     'ubuntu-22.04' ),
	(  'aarch64' ,           'linux',         'gnu',           'static',            'linux', 'ubuntu-22.04-arm' ),
	(   'x86_64' ,         'windows',       'mingw',           'static',          'windows',     'windows-2022' ),
	(      'x86' ,         'windows',       'mingw',           'static',          'windows',     'windows-2022' ), # windows xp
	(  'x86_old' ,         'windows',       'mingw',           'static',          'windows',     'windows-2022' ), # windows xp, no sse
	(   'x86_64' ,         'windows',        'msvc',           'static',          'windows',     'windows-2022' ),
	(   'x86_64' ,         'windows',        'msvc',          'dynamic',          'windows',     'windows-2022' ),
	(      'x86' ,         'windows',        'msvc',           'static',          'windows',     'windows-2022' ),
	(      'x86' ,         'windows',        'msvc',          'dynamic',          'windows',     'windows-2022' ),
	(  'aarch64' ,         'windows',        'msvc',           'static',          'windows',     'windows-2022' ),
	(  'aarch64' ,         'windows',        'msvc',          'dynamic',          'windows',     'windows-2022' ),
	(   'x86_64' ,          'darwin',       'macos',           'static',           'darwin',   'macos-15-intel' ),
	(  'aarch64' ,          'darwin',       'macos',           'static',           'darwin',         'macos-15' ),
	(      'x86' ,         'android',      'bionic',           'static',            'linux',     'ubuntu-22.04' ),
	(   'x86_64' ,         'android',      'bionic',           'static',            'linux',     'ubuntu-22.04' ),
	(      'arm' ,         'android',      'bionic',           'static',            'linux',     'ubuntu-22.04' ),
	(  'aarch64' ,         'android',      'bionic',           'static',            'linux',     'ubuntu-22.04' ),
	(   'wasm32' ,      'emscripten',  'emscripten',           'static',            'linux',     'ubuntu-22.04' ),
]:
	for debug_release in [ 'debug', 'release' ]:
		job_name = f'build+target={bsh_host_arch}-{bsh_host_platform}-{bsh_host_libc}-{bsh_static_dynamic}-{debug_release}'
		if bsh_build_platform != bsh_host_platform:
			job_name += f'+bplatform={bsh_build_platform}'
		configurations.append({
			'bsh_build_platform': bsh_build_platform,
			'bsh_host_arch': bsh_host_arch,
			'bsh_host_platform': bsh_host_platform,
			'bsh_host_libc': bsh_host_libc,
			'bsh_static_dynamic': bsh_static_dynamic,
			'bsh_debug_release': debug_release,
			'force_msys2_bash': (bsh_host_platform == 'windows' and bsh_host_libc == 'mingw') and 'yes' or 'no',
			'runs_on': runs_on,
			'asset_name': f'tpt-libs-prebuilt-{bsh_host_arch}-{bsh_host_platform}-{bsh_host_libc}-{bsh_static_dynamic}-{debug_release}-{vtag}',
			'job_name': job_name,
		})

set_output('matrix', json.dumps({ 'include': configurations }))
set_output('do_release', ref.startswith('refs/tags/v') and 'yes' or 'no')
