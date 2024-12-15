import Window from "@/common/window";
import icons from "@/utils/icons";
import { bind } from "astal";
import { Astal, Gtk } from "astal/gtk3";
import Mpris from "gi://AstalMpris";

const WINDOW_NAME = "media";

export default function Media() {
  const SpotifyInfo = () => {
    const spotify = Mpris.Player.new("spotify");

    return (
      <>
        {bind(spotify, "available").as((available) =>
          available ? (
            <box>
              <box
                className="Cover"
                css={bind(spotify, "coverArt").as(
                  (cover) => `background-image: url('${cover}');`,
                )}
              />
              <box vertical className="Player">
                <label
                  label={bind(spotify, "title")}
                  className="Title"
                  xalign={0} // Align label left
                  wrap
                />
                <label
                  label={bind(spotify, "artist")}
                  className="Artist"
                  xalign={0}
                  truncate
                />
                <label
                  label={bind(spotify, "album")}
                  className="Album"
                  xalign={0}
                  truncate
                />
                <box expand valign={Gtk.Align.END} halign={Gtk.Align.START}>
                  <circularprogress
                    startAt={0.75}
                    endAt={0.75}
                    value={bind(spotify, "position").as(
                      (position) => position / spotify.length,
                    )}
                    rounded
                    className="Progress"
                  >
                    <button
                      onClicked={() => spotify.play_pause()}
                      css="all: unset;"
                    >
                      <icon
                        icon={bind(spotify, "playbackStatus").as((status) =>
                          status === Mpris.PlaybackStatus.PLAYING
                            ? icons.media.playing
                            : icons.media.stopped,
                        )}
                      />
                    </button>
                  </circularprogress>
                </box>
              </box>
            </box>
          ) : (
            <label label="No media playing" className="Title" />
          ),
        )}
      </>
    );
  };

  return (
    <Window name={WINDOW_NAME} anchor={Astal.WindowAnchor.BOTTOM}>
      <box className="Media base">
        <SpotifyInfo />
      </box>
    </Window>
  );
}
