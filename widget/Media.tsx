import Window from "@/common/window";
import icons from "@/util/icons";
import { createBinding } from "ags";
import { Astal, Gtk } from "ags/gtk4";
import Mpris from "gi://AstalMpris";
import Pango from "gi://Pango";

const WINDOW_NAME = "media";

export default function Media() {
  const SpotifyInfo = () => {
    const spotify = Mpris.Player.new("spotify");

    return (
      <>
        <box
          class="min-w-[800px]"
          visible={createBinding(spotify, "available")}
        >
          <image
            file={createBinding(spotify, "coverArt")}
            class="min-h-[350px] min-w-[350px] rounded-lg"
            overflow={Gtk.Overflow.HIDDEN}
          />
          <box orientation={Gtk.Orientation.VERTICAL} hexpand class="p-10">
            <label
              label={createBinding(spotify, "title")}
              class="font-black mb-3 text-on_surface text-3xl"
              xalign={0} // Align label left
              wrap
              maxWidthChars={10} // How work ???
            />
            <label
              label={createBinding(spotify, "artist")}
              class="text-xl mb-2 font-medium text-on_surface_variant"
              xalign={0}
              ellipsize={Pango.EllipsizeMode.END}
            />
            <label
              label={createBinding(spotify, "album")}
              class="text-lg font-medium text-on_surface_variant"
              xalign={0}
              ellipsize={Pango.EllipsizeMode.END}
              maxWidthChars={10} // How work ???
            />
            <box valign={Gtk.Align.END} halign={Gtk.Align.START} vexpand>
              {/*
                  <circularprogress
                    startAt={0.75}
                    endAt={0.75}
                    value={createBinding(spotify, "position").as(
                      (position) => position / spotify.length,
                    )}
                    rounded
                    className="Progress"
                  >
                  */}
              <button onClicked={() => spotify.play_pause()}>
                <image
                  iconName={createBinding(spotify, "playbackStatus").as(
                    (status) =>
                      status === Mpris.PlaybackStatus.PLAYING
                        ? icons.media.playing
                        : icons.media.stopped,
                  )}
                />
              </button>
              {/*
                    </circularprogress>
                  */}
            </box>
          </box>
        </box>

        <label
          label="No Media Playing"
          class="text-2xl p-5"
          visible={!createBinding(spotify, "available")}
        />
      </>
    );
  };

  return (
    <Window name={WINDOW_NAME} anchor={Astal.WindowAnchor.BOTTOM}>
      <box class="p-1 bg-surface_container_lowest rounded-xl">
        <SpotifyInfo />
      </box>
    </Window>
  );
}
