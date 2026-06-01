using Gtk;
using GLib;

namespace Singularity.Apps.Music {

    public class MusicApp : Singularity.Application {

        private MusicWindow? _window = null;

        public MusicApp () {
            Object (application_id: "dev.sinty.music",
                    flags: GLib.ApplicationFlags.HANDLES_OPEN);
        }

        protected override void activate () {
            string[] gst_args = {};
            unowned string[] ua = gst_args;
            Gst.init (ref ua);

            if (_window == null) {
                _setup_styles ();
                _window = new MusicWindow (this);
            }
            _window.present ();
        }

        private void _setup_styles () {
            var provider = new Gtk.CssProvider ();
            provider.load_from_data (MUSIC_CSS.data);
            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (), provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        private const string MUSIC_CSS = """
/* now-playing page */
.music-now-playing * {
    color: white;
}

.music-now-cover {
    border-radius: 16px;
    box-shadow: 0 8px 40px rgba(0, 0, 0, 0.6);
    background-color: rgba(255, 255, 255, 0.08);
}

.music-now-title {
    font-size: 22px;
    font-weight: bold;
}

.music-now-artist {
    font-size: 14px;
    opacity: 0.75;
}

.music-now-album {
    font-size: 12px;
    opacity: 0.5;
}

.music-time {
    font-size: 12px;
    opacity: 0.6;
    font-variant-numeric: tabular-nums;
}

.music-ctrl {
    min-width: 40px;
    min-height: 40px;
}

.music-play-btn {
    background-color: @accent_color;
    color: white;
    border-radius: 50%;
    min-width: 56px;
    min-height: 56px;
    padding: 0;
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.4);
}

.music-play-btn:hover {
    background-color: alpha(@accent_color, 0.85);
}

.music-now-playing button.flat:hover,
.music-now-playing button.circular:hover,
.music-now-playing button.music-ctrl:hover {
    background-color: rgba(255, 255, 255, 0.15);
}

.music-now-playing scale trough {
    background-color: rgba(255, 255, 255, 0.2);
    min-height: 4px;
}

.music-now-playing scale trough highlight {
    background-color: @accent_color;
}

.music-playlist-panel {
    border-right: 1px solid alpha(@border_color, 0.5);
}
""";

        protected override void open (GLib.File[] files, string hint) {
            activate ();
            string[] uris = {};
            foreach (var f in files) uris += f.get_uri ();
            _window.open_uris (uris);
        }
    }

    public static int main (string[] args) {
        Intl.setlocale(GLib.LocaleCategory.ALL, "");
        string locale_dir = "/usr/share/locale";
        try {
            string exe = GLib.FileUtils.read_link("/proc/self/exe");
            locale_dir = GLib.Path.build_filename(GLib.Path.get_dirname(GLib.Path.get_dirname(exe)), "share", "locale");
        } catch (GLib.Error e) { }
        Intl.bindtextdomain("singularity-music", locale_dir);
        Intl.bind_textdomain_codeset("singularity-music", "UTF-8");
        Intl.textdomain("singularity-music");

        var app = new MusicApp ();
        return app.run (args);
    }
}
