project('singularity-music', ['vala', 'c'],
  version: '0.1.0',
  meson_version: '>= 0.59.0'
)

i18n = import('i18n')
add_project_arguments('-DGETTEXT_PACKAGE="singularity-music"', language: 'c')
subdir('po')

gnome = import('gnome')
cc    = meson.get_compiler('c')

gtk_dep         = dependency('gtk4')
gee_dep         = dependency('gee-0.8')
gst_dep         = dependency('gstreamer-1.0')
gst_tag_dep     = dependency('gstreamer-tag-1.0')
gst_pbutils_dep = dependency('gstreamer-pbutils-1.0')
soup_dep        = dependency('libsoup-3.0')
math_dep        = cc.find_library('m')

libsingularity_dep = dependency('singularity-1.0',
  fallback: ['libsingularity', 'libsingularity_dep']
)

if not meson.is_subproject() and libsingularity_dep.type_name() == 'internal'
  libsingularity_vapi_dir = join_paths(meson.project_build_root(), 'subprojects', 'libsingularity')
  add_project_arguments(['--vapidir=' + libsingularity_vapi_dir], language: 'vala')
endif

subdir('ui')

resources = gnome.compile_resources(
  'singularity-music-resources',
  'resources/dev.sinty.music.gresource.xml',
  source_dir: [meson.current_source_dir(), meson.current_build_dir()],
  dependencies: now_playing_ui
)

sources = files(
  'src/main.vala',
  'src/music_window.vala',
  'src/now_playing_page.vala',
  'src/mpris_exporter.vala',
  'src/mini_player.vala',
  'src/gst_audio_player.vala',
  'src/playlist.vala',
  'src/track_info.vala',
)

executable('singularity-music',
  sources + [resources],
  dependencies: [gtk_dep, gee_dep, gst_dep, gst_tag_dep, gst_pbutils_dep, math_dep, libsingularity_dep],
  install: true
)

shared_module('singularity-music-widget',
  files('widget/now_playing_widget.vala'),
  dependencies: [gtk_dep, soup_dep, libsingularity_dep],
  install: true,
  install_dir: get_option('libdir') / 'singularity' / 'widgets'
)
install_data('widget/dev.sinty.music.now-playing.widget',
  install_dir: get_option('datadir') / 'singularity' / 'widgets'
)

install_data('data/dev.sinty.music.desktop',
  install_dir: get_option('datadir') / 'applications'
)
install_data('data/dev.sinty.music.json',
  install_dir: get_option('datadir') / 'singularity' / 'app-settings'
)
install_data('data/icons/dev.sinty.music.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps'
)
