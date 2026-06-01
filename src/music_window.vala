using Gtk;
using GLib;
using Gee;

namespace Singularity.Apps.Music {

    public class MusicWindow : Singularity.Widgets.Window {

        // ── Backend ──────────────────────────────────────────────────────────
        private GstAudioPlayer _player;
        private Playlist       _playlist;
        private MprisExporter  _mpris;

        // ── Mini player ──────────────────────────────────────────────────────
        private MiniPlayer? _mini      = null;
        private bool        _mini_mode = false;

        // ── UI ───────────────────────────────────────────────────────────────
        private Stack                       _root_stack;
        private NowPlayingPage              _now_playing;
        private Button _mini_btn;

        // Playlist popover (anchored to now_playing.playlist_btn)
        private ListBox  _playlist_box;
        private Popover? _playlist_popover = null;

        private int _repeat_mode = 0;

        // ── Constructor ──────────────────────────────────────────────────────

        public MusicWindow (Gtk.Application app) {
            Object (application: app);
            default_width  = 800;
            default_height = 560;
            title = "Music";

            _player   = new GstAudioPlayer ();
            _playlist = new Playlist ();
            _mpris    = new MprisExporter ();
            _mpris.start ();

            // Wire MPRIS controls back to player
            _mpris.player_obj.play_pause_requested.connect (() => {
                _player.toggle_play_pause ();
                _now_playing?.set_playing (_player.is_playing);
                _mpris.update_playback (_player.is_playing);
            });
            _mpris.player_obj.next_requested.connect (() => _play_track (_playlist.next ()));
            _mpris.player_obj.previous_requested.connect (() => _play_track (_playlist.prev ()));

            // Full flat mode: no toolbar, drag strip + close btn overlay instead
            flat = true;
            show_close = true;

            _build_ui ();
            _connect_signals ();
        }

        // ── Layout ───────────────────────────────────────────────────────────

        private void _build_ui () {
            _root_stack = new Stack ();
            _root_stack.transition_type     = StackTransitionType.CROSSFADE;
            _root_stack.transition_duration = 200;
            _root_stack.hexpand = true;
            _root_stack.vexpand = true;

            // ── Welcome page ─────────────────────────────────────────────────
            var wp = new Singularity.Widgets.WelcomePage ();
            wp.app_icon_name = "dev.sinty.music";
            wp.title    = "Music";
            wp.subtitle = "Play your music collection";
            wp.add_action (
                "document-open-symbolic",
                "Open Files",
                "Add audio files or entire folders to the playlist.",
                () => _open_files ()
            );
            _root_stack.add_named (wp, "welcome");

            // ── Now-playing (full window, draws its own bg) ──────────────────
            _now_playing = new NowPlayingPage ();
            _now_playing.play_pause_clicked.connect (() => {
                _player.toggle_play_pause ();
                _now_playing.set_playing (_player.is_playing);
                if (_mini != null) _mini.update_playback (_player.is_playing);
            });
            _now_playing.prev_clicked.connect (() => _play_track (_playlist.prev ()));
            _now_playing.next_clicked.connect (() => _play_track (_playlist.next ()));
            _now_playing.shuffle_clicked.connect (_toggle_shuffle);
            _now_playing.repeat_clicked.connect (_cycle_repeat);
            _now_playing.seek_requested.connect ((frac) => {
                int64 dur = _player.get_duration ();
                if (dur > 0) _player.seek ((int64)(frac * dur));
            });
            _now_playing.volume_changed.connect ((v) => _player.set_volume (v));

            // Playlist popover on the playlist button
            _now_playing.playlist_btn.clicked.connect (_show_playlist_popover);

            // Bubble bar via the Window API. The mini-player toggle is
            // only meaningful on the player page; toggle its visibility
            // when the root stack changes child.
            _mini_btn = add_bubble_icon ("go-down-symbolic", "Mini Player",
                                         () => _toggle_mini_player ());
            _mini_btn.visible = false;

            _root_stack.add_named (_now_playing, "player");
            _root_stack.visible_child_name = "welcome";
            _root_stack.notify["visible-child-name"].connect (() => {
                _mini_btn.visible = (_root_stack.visible_child_name == "player");
            });
            set_content (_root_stack);
        }

        // ── Playlist popover ──────────────────────────────────────────────────

        private void _show_playlist_popover () {
            if (_playlist_popover == null) {
                var box = new Box (Orientation.VERTICAL, 0);
                box.set_size_request (300, -1);

                var header = new Box (Orientation.HORIZONTAL, 0);
                header.margin_start  = 12;
                header.margin_end    = 4;
                header.margin_top    = 8;
                header.margin_bottom = 4;

                var lbl = new Label ("Playlist");
                lbl.add_css_class ("heading");
                lbl.halign  = Align.START;
                lbl.hexpand = true;
                header.append (lbl);

                var add_btn = new Button.from_icon_name ("list-add-symbolic");
                add_btn.add_css_class ("flat");
                add_btn.tooltip_text = "Add Files";
                add_btn.clicked.connect (() => {
                    _playlist_popover.popdown ();
                    _open_files ();
                });
                header.append (add_btn);

                var clear_btn = new Button.from_icon_name ("edit-clear-all-symbolic");
                clear_btn.add_css_class ("flat");
                clear_btn.tooltip_text = "Clear Playlist";
                clear_btn.clicked.connect (() => {
                    _playlist_popover.popdown ();
                    _playlist.clear ();
                });
                header.append (clear_btn);
                box.append (header);

                var sep = new Separator (Orientation.HORIZONTAL);
                sep.margin_bottom = 4;
                box.append (sep);

                var scroll = new ScrolledWindow ();
                scroll.vexpand            = true;
                scroll.hscrollbar_policy  = PolicyType.NEVER;
                scroll.set_size_request (-1, 320);

                _playlist_box = new ListBox ();
                _playlist_box.selection_mode = SelectionMode.SINGLE;
                _playlist_box.row_activated.connect ((row) => {
                    _playlist_popover.popdown ();
                    _play_track (_playlist.play_index (row.get_index ()));
                });

                // Populate with any tracks already in the playlist
                for (int i = 0; i < _playlist.count; i++) {
                    var t = _playlist.get_track (i);
                    if (t != null) _add_playlist_row (t);
                }
                if (_playlist.current_index >= 0) {
                    var row = _playlist_box.get_row_at_index (_playlist.current_index);
                    if (row != null) _playlist_box.select_row (row);
                }

                scroll.set_child (_playlist_box);
                box.append (scroll);

                _playlist_popover = new Popover ();
                _playlist_popover.set_child (box);
                _playlist_popover.set_parent (_now_playing.playlist_btn);
                _playlist_popover.has_arrow = true;
            }

            _playlist_popover.popup ();
        }

        // ── Signal wiring ─────────────────────────────────────────────────────

        private void _connect_signals () {
            _player.position_updated.connect ((pos, dur) => {
                _now_playing.update_position (pos, dur);
                _mpris.update_position (pos);
                if (_mini != null) _mini.update_position (pos, dur);
            });

            _player.track_ended.connect (() => {
                var next = _playlist.next ();
                if (next != null) {
                    _play_track (next);
                } else {
                    _now_playing.set_playing (false);
                    _mpris.set_stopped ();
                    if (_mini != null) _mini.update_playback (false);
                }
            });

            _player.metadata_ready.connect ((title, artist, album, dur, cover) => {
                var t = _playlist.current_track;
                if (t == null) return;
                if (title  != null) t.title  = title;
                if (artist != null) t.artist = artist;
                if (album  != null) t.album  = album;
                if (dur > 0) t.duration = dur;
                if (cover  != null) t.cover  = cover;
                _now_playing.update_track (t);
                _mpris.update_track (t, t.cover != null ? (t.cover as Gdk.Texture) : null);
                if (_mini != null) _mini.update_track (t);
            });

            _player.error_occurred.connect ((msg) => warning ("GstAudioPlayer: %s", msg));

            _playlist.track_added.connect ((track) => _add_playlist_row (track));

            _playlist.cleared.connect (() => {
                if (_playlist_box != null) {
                    Widget? c = _playlist_box.get_first_child ();
                    while (c != null) {
                        var next = c.get_next_sibling ();
                        _playlist_box.remove (c);
                        c = next;
                    }
                }
                _root_stack.visible_child_name = "welcome";
                show_close = true;
                _now_playing.update_track (null);
            });

            _playlist.current_changed.connect ((track) => {
                if (track != null) _now_playing.update_track (track);
                if (_playlist_box != null && _playlist.current_index >= 0) {
                    var row = _playlist_box.get_row_at_index (_playlist.current_index);
                    if (row != null) _playlist_box.select_row (row);
                }
            });
        }

        // ── Playlist row ──────────────────────────────────────────────────────

        private void _add_playlist_row (TrackInfo track) {
            if (_playlist_box == null) return;
            var row  = new ListBoxRow ();
            var hbox = new Box (Orientation.HORIZONTAL, 8);
            hbox.margin_start  = 12;
            hbox.margin_end    = 12;
            hbox.margin_top    = 6;
            hbox.margin_bottom = 6;

            var num = new Label ("%d".printf (_playlist.count));
            num.add_css_class ("dim-label");
            num.width_chars = 2;
            num.xalign = 1.0f;

            var info = new Box (Orientation.VERTICAL, 1);
            info.hexpand = true;

            var tl = new Label (track.title);
            tl.halign    = Align.START;
            tl.ellipsize = Pango.EllipsizeMode.END;

            var al = new Label (track.artist != "Unknown Artist" ? track.artist : "");
            al.halign = Align.START;
            al.add_css_class ("dim-label");
            al.add_css_class ("caption");
            al.ellipsize = Pango.EllipsizeMode.END;

            info.append (tl);
            info.append (al);
            hbox.append (num);
            hbox.append (info);
            row.set_child (hbox);
            _playlist_box.append (row);
        }

        // ── Playback helpers ──────────────────────────────────────────────────

        private void _play_track (TrackInfo? track) {
            if (track == null) return;
            _player.load_uri (track.uri);
            _player.play ();
            _now_playing.update_track (track);
            _now_playing.set_playing (true);
            _mpris.update_track (track, track.cover != null ? (track.cover as Gdk.Texture) : null);
            _mpris.update_playback (true);
            _root_stack.visible_child_name = "player";
            show_close = false;
            if (_playlist_box != null) {
                var row = _playlist_box.get_row_at_index (_playlist.current_index);
                if (row != null) _playlist_box.select_row (row);
            }
            if (_mini != null) {
                _mini.update_track (track);
                _mini.update_playback (true);
            }
        }

        private void _toggle_shuffle () {
            _playlist.shuffle = !_playlist.shuffle;
            _now_playing.set_shuffle_active (_playlist.shuffle);
        }

        private void _cycle_repeat () {
            _repeat_mode = (_repeat_mode + 1) % 3;
            _playlist.repeat_all = (_repeat_mode == 1);
            _playlist.repeat_one = (_repeat_mode == 2);
            _now_playing.set_repeat_state (_repeat_mode);
        }

        private void _toggle_mini_player () {
            if (_mini_mode) {
                if (_mini != null) _mini.hide ();
                present ();
                _mini_mode = false;
            } else {
                if (_mini == null) {
                    _mini = new MiniPlayer (application);
                    _mini.play_pause_clicked.connect (() => {
                        _player.toggle_play_pause ();
                        bool p = _player.is_playing;
                        _now_playing.set_playing (p);
                        _mini.update_playback (p);
                    });
                    _mini.prev_clicked.connect (() => _play_track (_playlist.prev ()));
                    _mini.next_clicked.connect (() => _play_track (_playlist.next ()));
                    _mini.seek_requested.connect ((frac) => {
                        int64 dur = _player.get_duration ();
                        if (dur > 0) _player.seek ((int64)(frac * dur));
                    });
                    _mini.expand_clicked.connect (() => {
                        _mini_mode = false;
                        _mini.hide ();
                        present ();
                    });
                    _mini.update_track (_playlist.current_track);
                    _mini.update_playback (_player.is_playing);
                }
                _mini.present ();
                hide ();
                _mini_mode = true;
            }
        }

        // ── File open dialog ──────────────────────────────────────────────────

        private void _open_files () {
            var dialog = new FileDialog ();
            dialog.title = "Open Audio Files";
            var filters      = new GLib.ListStore (typeof (FileFilter));
            var audio_filter = new FileFilter ();
            audio_filter.name = "Audio Files";
            audio_filter.add_mime_type ("audio/*");
            filters.append (audio_filter);
            dialog.filters = filters;
            dialog.open_multiple.begin (this, null, (obj, res) => {
                try {
                    var files = dialog.open_multiple.end (res);
                    string[] uris = {};
                    for (int i = 0; i < (int) files.get_n_items (); i++) {
                        var f = files.get_item (i) as File;
                        if (f != null) uris += f.get_uri ();
                    }
                    _playlist.add_uris (uris);
                    if (_playlist.count > 0 && _playlist.current_index < 0)
                        _play_track (_playlist.play_index (0));
                } catch {}
            });
        }

        // ── Public API ────────────────────────────────────────────────────────

        public void open_uris (string[] uris) {
            _playlist.add_uris (uris);
            if (_playlist.current_index < 0 && _playlist.count > 0)
                _play_track (_playlist.play_index (0));
        }
    }
}

