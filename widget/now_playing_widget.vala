using Gtk;
using GLib;
using Singularity;

namespace SingularityMusicWidget {

    /**
     * Now Playing widget for the overview. This is a *very* thin shell on top
     * of Singularity.Widgets.MediaPlayerCard - the same component the sidebar
     * uses. We just turn on `always_visible` so the slot doesn't collapse
     * when nothing is playing.
     *
     * The widget code lives in a shared module (libsingularity-music-widget.so)
     * loaded by the overview process itself; it does NOT require the music
     * app to be running, because the MediaPlayerCard talks to any MPRIS
     * player on the session bus.
     */
    public class NowPlayingProvider : Object, OverviewWidgetProvider {
        public string id           { get { return "music.now-playing"; } }
        public string provider_id  { get { return "dev.sinty.music"; } }
        public string display_name { get { return "Now Playing"; } }
        public string icon_name    { get { return "audio-x-generic-symbolic"; } }
        public WidgetSize[] supported_sizes {
            get {
                if (_sizes == null) {
                    _sizes = new WidgetSize[4];
                    _sizes[0] = WidgetSize(1, 1);
                    _sizes[1] = WidgetSize(1, 2);
                    _sizes[2] = WidgetSize(2, 1);
                    _sizes[3] = WidgetSize(2, 2);
                }
                return _sizes;
            }
        }
        private WidgetSize[] _sizes;

        public Gtk.Widget create_instance(string instance_id, WidgetSize size, Variant? config) {
            // The card was designed for the narrow sidebar (~340px) and its
            // intrinsic height is short. Centre it inside the cell so the
            // remaining grid space doesn't appear as dead air below the
            // controls.
            var card = new Singularity.Widgets.MediaPlayerCard();
            card.always_visible = true;
            card.hexpand = true;
            card.vexpand = true;
            card.halign = Align.FILL;
            card.valign = Align.FILL;
            return card;
        }
    }

    [CCode (cname = "singularity_music_widget_new")]
    public static Object singularity_music_widget_new() {
        return new NowPlayingProvider();
    }
}
