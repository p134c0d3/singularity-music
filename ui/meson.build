vetro = find_program('vetro')

vetro_gir = []
if meson.is_subproject()
  vetro_gir = ['--gir', subproject('libsingularity').get_variable('libsingularity_gir')]
endif

now_playing_ui = custom_target(
  'now_playing_ui_gen',
  input: 'now_playing.vetro',
  output: 'now_playing.ui',
  command: [vetro] + vetro_gir + ['--in', '@INPUT@', '--out', '@OUTPUT@'],
  install: false,
  build_by_default: true
)
