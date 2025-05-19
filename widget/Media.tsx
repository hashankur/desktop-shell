import Mpris from "gi://AstalMpris";
import Pango from "gi://Pango";
import Window from "@/common/window";
import icons from "@/util/icons";
import { bind } from "astal";
import { Astal, Gtk } from "astal/gtk4";

const WINDOW_NAME = "media";

export default function Media() {
  const SpotifyInfo = () => {
    const spotify = Mpris.Player.new("spotify");

    return (
      <>
        {bind(spotify, "available").as((available) =>
          available ? (
            <box cssClasses={["min-w-[800px]"]}>
              <image
                file={bind(spotify, "coverArt")}
                cssClasses={["min-h-[350px]", "min-w-[350px]", "rounded-lg"]}
                overflow={Gtk.Overflow.HIDDEN}
              />
              <box vertical hexpand cssClasses={["p-10"]}>
                <label
                  label={bind(spotify, "title")}
                  cssClasses={[
                    "font-black",
                    "mb-3",
                    "text-on_surface",
                    "text-3xl",
                  ]}
                  xalign={0} // Align label left
                  wrap
                  maxWidthChars={10} // How work ???
                />
                <label
                  label={bind(spotify, "artist")}
                  cssClasses={[
                    "text-xl",
                    "mb-2",
                    "font-medium",
                    "text-on_surface_variant",
                  ]}
                  xalign={0}
                  ellipsize={Pango.EllipsizeMode.END}
                />
                <label
                  label={bind(spotify, "album")}
                  cssClasses={[
                    "text-lg",
                    "font-medium",
                    "text-on_surface_variant",
                  ]}
                  xalign={0}
                  ellipsize={Pango.EllipsizeMode.END}
                  maxWidthChars={10} // How work ???
                />
                <box valign={Gtk.Align.END} halign={Gtk.Align.START} vexpand>
                  {/*
                  <circularprogress
                    startAt={0.75}
                    endAt={0.75}
                    value={bind(spotify, "position").as(
                      (position) => position / spotify.length,
                    )}
                    rounded
                    className="Progress"
                  >
                  */}
                  <button onClicked={() => spotify.play_pause()}>
                    <image
                      iconName={bind(spotify, "playbackStatus").as((status) =>
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
          ) : (
            <label label="No Media Playing" cssClasses={["text-2xl", "p-5"]} />
          ),
        )}
      </>
    );
  };

  return (
    <Window name={WINDOW_NAME} anchor={Astal.WindowAnchor.BOTTOM}>
      <box cssClasses={["p-1", "bg-surface_container_lowest", "rounded-xl"]}>
        <SpotifyInfo />
      </box>
    </Window>
  );
}
