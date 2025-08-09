import Window from "@/common/window";
import icons from "@/util/icons";
import { With } from "ags";
import { createBinding } from "ags";
import { Astal, Gtk } from "ags/gtk4";
import Mpris from "gi://AstalMpris";
import Pango from "gi://Pango";

const WINDOW_NAME = "media";

const SpotifyInfo = () => {
  const spotify = Mpris.Player.new("spotify");
  const available = createBinding(spotify, "available");

  return (
    <box class="min-w-[800px]">
      <image
        iconName={icons.media.fallback}
        class="min-h-[350px] min-w-[350px] rounded-lg bg-secondary_container text-secondary"
        pixelSize={100}
        visible={available((v) => !v)}
      />
      <image
        file={createBinding(spotify, "coverArt")}
        class="min-h-[350px] min-w-[350px] rounded-lg"
        overflow={Gtk.Overflow.HIDDEN}
        visible={available}
      />
      <box orientation={Gtk.Orientation.VERTICAL} hexpand class="p-10">
        <label
          label="No Media Playing"
          class="font-black text-on_surface text-3xl"
          vexpand
          valign={Gtk.Align.CENTER}
          wrap
          maxWidthChars={10}
          visible={available((v) => !v)}
        />
        <label
          label={createBinding(
            spotify,
            "title",
          )((title) => title || "Unknown Title")}
          class="font-black mb-3 text-on_surface text-3xl"
          xalign={0} // Align label left
          wrap
          maxWidthChars={10} // How work ???
          visible={available}
        />
        <label
          label={createBinding(
            spotify,
            "artist",
          )((artist) => artist || "Unknown Artist")}
          class="text-xl mb-2 font-medium text-on_surface_variant"
          xalign={0}
          ellipsize={Pango.EllipsizeMode.END}
          visible={available}
        />
        <label
          label={createBinding(
            spotify,
            "album",
          )((album) => album || "Unknown Album")}
          class="text-lg font-medium text-on_surface_variant"
          xalign={0}
          ellipsize={Pango.EllipsizeMode.END}
          maxWidthChars={10} // How work ???
          visible={available}
        />
        <box
          valign={Gtk.Align.END}
          halign={Gtk.Align.START}
          vexpand
          visible={available}
        >
          <button onClicked={() => spotify.play_pause()}>
            <image
              iconName={createBinding(
                spotify,
                "playbackStatus",
              )((status) =>
                status === Mpris.PlaybackStatus.PLAYING
                  ? icons.media.playing
                  : icons.media.stopped,
              )}
            />
          </button>
        </box>
      </box>
    </box>
  );
};

export default function Media() {
  return (
    <Window name={WINDOW_NAME} anchor={Astal.WindowAnchor.BOTTOM}>
      <box class="p-1 bg-surface_container_lowest rounded-xl">
        <SpotifyInfo />
      </box>
    </Window>
  );
}
