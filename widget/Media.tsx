import Window from "@/common/window";
import icons from "@/utils/icons";
import { bind } from "astal";
import { Astal, Gtk } from "astal/gtk4";
import Mpris from "gi://AstalMpris";
import Pango from "gi://Pango";

const WINDOW_NAME = "media";

export default function Media() {
  const SpotifyInfo = () => {
    const spotify = Mpris.Player.new("spotify");

    return (
      <>
        {bind(spotify, "available").as((available) =>
          available ? (
            <box cssClasses={["m-5", "bg-base", "rounded-xl", "min-w-[800px]"]} overflow={Gtk.Overflow.HIDDEN}>
              <image
                file={bind(spotify, "coverArt")}
                cssClasses={["min-h-[350px]", "min-w-[350px]"]}
              />
              <box vertical hexpand cssClasses={["p-10"]}>
                <label
                  label={bind(spotify, "title")}
                  cssClasses={["text-4xl", "font-black", "mb-3"]}
                  xalign={0} // Align label left
                  wrap
                />
                <label
                  label={bind(spotify, "artist")}
                  cssClasses={["text-2xl", "mb-2"]}
                  xalign={0}
                  ellipsize={Pango.EllipsizeMode.END}
                />
                <label
                  label={bind(spotify, "album")}
                  cssClasses={["text-lg", "font-normal"]}
                  xalign={0}
                  ellipsize={Pango.EllipsizeMode.END}
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
            </box >
          ) : (
            <label label="No media playing" cssName="Title" />
          ),
        )
        }
      </>
    );
  };

  return (
    <Window name={WINDOW_NAME} anchor={Astal.WindowAnchor.BOTTOM}>
      <SpotifyInfo />
    </Window>
  );
}
