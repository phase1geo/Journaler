  project('com.github.phase1geo.journaler', ['vala', 'c'],
    meson_version : '>= 0.56.0',
    version : '0.1',
    license: 'GPL-3.0'
)

i18n  = import('i18n')
gnome = import('gnome')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')

config_data = configuration_data()
config_data.set_quoted('LOCALEDIR', get_option('prefix') / get_option('localedir'))
config_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
config_file = configure_file(
    input: 'src/Config.vala.in',
    output: '@BASENAME@',
    configuration: config_data
)

gresource = gnome.compile_resources(
    'journaler-resources', 'data/' + meson.project_name() + '.gresource.xml',
    build_by_default: true,
    source_dir: 'data',
)

sources = files()

subdir('data')
subdir('po')
subdir('src')

core_deps = [
    dependency('gobject-2.0'),
    dependency('glib-2.0'),
    meson.get_compiler('vala').find_library('posix'),
    meson.get_compiler('c').find_library('m', required : false),
    meson.get_compiler('c').find_library('markdown', required : true),
    meson.get_compiler('c').find_library('gcrypt', required : true),
    dependency('gee-0.8'),
    dependency('granite-7'),
    dependency('gtk4'),
    dependency('libxml-2.0'),
    dependency('gtksourceview-5'),
    dependency('sqlite3'),
    dependency('json-glib-1.0')
]

e = executable('com.github.phase1geo.journaler',
    sources,
    config_file,
    gresource,
    dependencies: core_deps,
    vala_args: [
        meson.project_source_root() + '/vapi/libmarkdown.vapi',
        meson.project_source_root() + '/vapi/gcrypt.vapi'
    ],
    install : true
)

d = executable('com.github.phase1geo.journaler.daemon',
    files('src/Daemon.vala'),
    dependencies: [
      dependency('gobject-2.0'),
      dependency('glib-2.0')
    ],
    install : true
)

meson.add_install_script('meson/post_install.py')

