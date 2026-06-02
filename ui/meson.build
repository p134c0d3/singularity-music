vetro = find_program('vetro')

now_playing_ui = custom_target(
  'now_playing_ui_gen',
  input: 'now_playing.vetro',
  output: 'now_playing.ui',
  command: [vetro, '--in', '@INPUT@', '--out', '@OUTPUT@'],
  install: false,
  build_by_default: true
)
