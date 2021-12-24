project('tpt-libs-prebuilt-win64-static', ['c', 'cpp'])

cpp_compiler = meson.get_compiler('cpp')
uopt_lua = get_option('lua')

lib_inv = {
	'zlib'    : [ 'z'     , [] ],
	'sdl2'    : [ 'SDL2'  , [] ],
	'fftw'    : [ 'fftw3f', [] ],
	'libcurl' : [ 'curl'  , [] ],
	'lua52'   : [ 'lua5.2', [] ],
	'lua51'   : [ 'lua5.1', [] ],
	'luajit'  : [ 'luajit', [] ],
}
other_libs = [
	'shell32',
	'wsock32',
	'user32',
	'advapi32',
	'ws2_32',
	'wldap32',
	'crypt32',
	'winmm',
	'gdi32',
	'version',
	'imm32',
	'setupapi',
]

incdirs = [ include_directories('include') ]
if uopt_lua == 'luajit'
	incdirs += include_directories('include/luajit-2.1')
elif uopt_lua == 'lua5.2'
	incdirs += include_directories('include/lua5.2')
elif uopt_lua == 'lua5.1'
	incdirs += include_directories('include/lua5.1')
else
	lua_opt_dep = []
endif

foreach name, inv : lib_inv
	library = cpp_compiler.find_library(inv[0], dirs: join_paths(meson.current_source_dir(), 'lib'))
	dependencies_of_library = []
	foreach depname : inv[1]
		dependencies_of_library += depname
	endforeach
	set_variable(name + '_dep', declare_dependency(
		include_directories: incdirs,
		dependencies: [ library, dependencies_of_library ]
	))
endforeach
other_fl = []
foreach name : other_libs
	other_fl += cpp_compiler.find_library(name)
endforeach
other_dep = declare_dependency(
	dependencies: other_fl
)
