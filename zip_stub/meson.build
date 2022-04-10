project('tpt-libs-prebuilt', [ 'c' ])

# begin block copied from tpt's meson.build
c_compiler = meson.get_compiler('c')
copt_x86 = false
copt_64bit = false
copt_msvc = false
if c_compiler.get_id() in [ 'msvc' ]
	copt_compiler = 'msvc'
	copt_msvc = true
elif c_compiler.get_id() in [ 'gcc', 'clang' ]
	copt_compiler = 'gcc'
else
	warning('unsupported compiler: ' + c_compiler.get_id() + '; you are on your own')
	copt_compiler = 'gcc'
endif
if host_machine.cpu_family() in [ 'x86_64' ]
	copt_architecture = 'x86_64'
	copt_x86 = true
	copt_64bit = true
elif host_machine.cpu_family() in [ 'x86' ]
	copt_architecture = 'i686'
	copt_x86 = true
elif host_machine.cpu_family() in [ 'aarch64' ]
	copt_architecture = 'arm64'
	copt_64bit = true
elif host_machine.cpu_family() in [ 'arm' ]
	copt_architecture = 'arm'
else
	warning('unsupported architecture: ' + host_machine.cpu_family() + '; you are on your own')
	copt_architecture = 'i686'
endif
if host_machine.system() in [ 'linux', 'freebsd' ]
	copt_platform = 'lin'
elif host_machine.system() in [ 'windows' ]
	copt_platform = 'win'
elif host_machine.system() in [ 'darwin' ]
	copt_platform = 'mac'
elif host_machine.system() in [ 'android' ]
	copt_platform = 'and'
else
	warning('unsupported platform: ' + host_machine.system() + '; you are on your own')
	copt_platform = 'lin'
endif
uopt_static = get_option('static')
use_tpt_libs = 'no'
if uopt_static == 'system'
	if copt_platform == 'win'
		error('no way to find static system libraries on windows')
	endif
elif uopt_static == 'prebuilt'
	use_tpt_libs = 'static'
else
	if copt_platform == 'win'
		use_tpt_libs = 'dynamic'
	endif
endif
# end block copied from tpt's meson.build

uopt_http = get_option('http')
uopt_lua  = get_option('lua')
uopt_ssl  = get_option('ssl')

incdirs = [
	include_directories('include'),
]
if copt_platform == 'and' and uopt_lua == 'luajit'
	uopt_lua = 'lua5.2'
endif
if uopt_lua == 'luajit'
	incdirs += [
		include_directories('include/luajit-2.1'),
	]
elif uopt_lua == 'lua5.2'
	incdirs += [
		include_directories('include/lua5.2'),
	]
elif uopt_lua == 'lua5.1'
	incdirs += [
		include_directories('include/lua5.1'),
	]
endif
if copt_platform == 'win'
	incdirs += [
		include_directories('include/win-dirent'),
	]
endif

mingw         = copt_platform == 'win' and copt_compiler == 'gcc'
mingw_static  = mingw and use_tpt_libs == 'static'
mingw_dynamic = mingw and use_tpt_libs == 'dynamic'
libraries = []
libraries += [ {
	'name': 'zlib',
	'lib_to_find': mingw_dynamic ? 'zlib1' : 'z',
	'other_libs_to_find': [],
	'other_dependencies': [],
	'dll_to_copy': 'zlib1.dll',
} ]
sdl2_other_libs_to_find = []
if copt_platform == 'lin'
	sdl2_other_libs_to_find += [ 'dl' ]
endif
if copt_platform == 'and'
	sdl2_other_libs_to_find += [ 'dl', 'GLESv1_CM', 'GLESv2', 'OpenSLES', 'log', 'android' ]
endif
libraries += [ {
	'name': 'sdl2',
	'lib_to_find': 'SDL2',
	'other_libs_to_find': sdl2_other_libs_to_find,
	'other_dependencies': copt_platform == 'mac' ? [ 'Cocoa', 'IOKit', 'CoreVideo', 'Carbon', 'Metal' ] : [],
	'dll_to_copy': 'SDL2.dll',
} ]
libraries += [ {
	'name': 'sdl2main',
	'lib_to_find': 'SDL2main',
	'other_libs_to_find': mingw ? [ 'mingw32' ] : [],
	'other_dependencies': [],
	'dll_to_copy': '',
} ]
libraries += [ {
	'name': 'fftw',
	'lib_to_find': mingw_dynamic ? 'fftw3f-3' : 'fftw3f',
	'other_libs_to_find': [],
	'other_dependencies': [],
	'dll_to_copy': mingw_dynamic ? 'libfftw3f-3.dll' : 'fftw3f.dll',
} ]
if copt_platform != 'and'
	libcurl_other_dependencies = []
	if copt_platform == 'mac'
		libcurl_other_dependencies += [ 'Security' ]
	endif
	if copt_platform == 'lin'
		libcurl_other_dependencies += [ uopt_ssl ]
	endif
	libraries += [ {
		'name': 'libcurl',
		'lib_to_find': mingw_dynamic ? 'curl-4' : 'curl',
		'other_libs_to_find': [],
		'other_dependencies': libcurl_other_dependencies,
		'dll_to_copy': mingw_dynamic ? 'libcurl-4.dll' : 'libcurl.dll',
	} ]
endif
libraries += [ {
	'name': 'lua52',
	'lib_to_find': 'lua5.2',
	'other_libs_to_find': [],
	'other_dependencies': [],
	'dll_to_copy': 'lua5.2.dll',
} ]
libraries += [ {
	'name': 'lua51',
	'lib_to_find': 'lua5.1',
	'other_libs_to_find': [],
	'other_dependencies': [],
	'dll_to_copy': 'lua5.1.dll',
} ]
if copt_platform != 'and'
	libraries += [ {
		'name': 'luajit',
		'lib_to_find': (copt_platform == 'win' and not mingw_static) ? 'luajit21' : 'luajit',
		'other_libs_to_find': [],
		'other_dependencies': [],
		'dll_to_copy': 'luajit21.dll',
	} ]
endif

config_dlls = []
foreach library : libraries
	name               = library['name']
	lib_to_find        = library['lib_to_find']
	other_libs_to_find = library['other_libs_to_find']
	other_dependencies = library['other_dependencies']
	dll_to_copy        = library['dll_to_copy']
	if copt_platform != 'win'
		lib_to_find = 'lib' + lib_to_find
	endif
	dependencies = [
		c_compiler.find_library(lib_to_find, dirs: join_paths(meson.current_source_dir(), 'lib')),
	]
	foreach other_lib_to_find : other_libs_to_find
		dependencies += [
			c_compiler.find_library(other_lib_to_find),
		]
	endforeach
	foreach other_dependency : other_dependencies
		dependencies += [
			dependency(other_dependency),
		]
	endforeach
	set_variable(name + '_dep', declare_dependency(
		include_directories: incdirs,
		dependencies: dependencies,
	))
	if copt_platform == 'win' and use_tpt_libs == 'dynamic' and dll_to_copy != ''
		config_dlls += [ [ files(join_paths(meson.current_source_dir(), 'lib', dll_to_copy)), dll_to_copy ] ]
	endif
endforeach

if copt_platform == 'win'
	other_lib_names = [
		'shell32',
		'wsock32',
		'user32',
		'advapi32',
		'ws2_32',
		'wldap32',
		'crypt32',
		'winmm',
		'gdi32',
	]
	if use_tpt_libs == 'static'
		other_lib_names += [
			'version',
			'imm32',
			'setupapi',
		]
	endif
	other_libs = []
	foreach name : other_lib_names
		other_libs += c_compiler.find_library(name)
	endforeach
	other_dep = declare_dependency(
		dependencies: other_libs,
	)
elif copt_platform == 'and'
	sdl_jar = files('lib/sdl.jar')
endif
