project('tpt-libs-prebuilt-win64-dynamic', ['c', 'cpp'])

cpp_compiler = meson.get_compiler('cpp')
uopt_lua = get_option('lua')

lib_inv = {
	'zlib'    : [ 'zlib1'   , 'zlib1.dll'       ],
	'sdl2'    : [ 'SDL2'    , 'SDL2.dll'        ],
	'fftw'    : [ 'fftw3f-3', 'libfftw3f-3.dll' ],
	'libcurl' : [ 'curl-4'  , 'libcurl-4.dll'   ],
	'lua52'   : [ 'lua5.2'  , 'lua5.2.dll'      ],
	'lua51'   : [ 'lua5.1'  , 'lua5.1.dll'      ],
	'luajit'  : [ 'luajit21', 'luajit21.dll'    ],
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

config_dlls = []
foreach name, inv : lib_inv
	set_variable(name + '_dep', declare_dependency(
		include_directories: incdirs,
		dependencies:cpp_compiler.find_library(inv[0], dirs: join_paths(meson.current_source_dir(), 'lib'))
	))
	if inv[1] != ''
		config_dlls += [ [ files(join_paths(meson.current_source_dir(), 'lib', inv[1])), inv[1] ] ]
	endif
endforeach
other_fl = []
foreach name : other_libs
	other_fl += cpp_compiler.find_library(name)
endforeach
other_dep = declare_dependency(
	dependencies: other_fl
)
