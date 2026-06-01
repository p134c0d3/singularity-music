using GLib;
using Gdk;

namespace Singularity.Apps.Music {

    public class TrackInfo : Object {
        public string uri { get; set; default = ""; }
        public string title { get; set; default = "Unknown Title"; }
        public string artist { get; set; default = "Unknown Artist"; }
        public string album { get; set; default = "Unknown Album"; }
        public int64 duration { get; set; default = 0; } // nanoseconds
        public Gdk.Paintable? cover { get; set; default = null; }

        public string display_duration {
            owned get {
                if (duration <= 0) return "0:00";
                int64 secs = duration / 1000000000;
                return "%d:%02d".printf ((int)(secs / 60), (int)(secs % 60));
            }
        }
    }
}
