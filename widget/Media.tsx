import { App, Astal, Gdk, Gtk } from "astal/gtk3";
import { bind } from "astal";
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
              <box vertical className="Player" valign={Gtk.Align.CENTER} expand>
                <label
                  halign={Gtk.Align.START}
                  label={bind(spotify, "title")}
                  className="Title"
                  truncate
                  // wrap
                />
                <label
                  halign={Gtk.Align.START}
                  label={bind(spotify, "artist")}
                  className="Artist"
                  truncate
                />
                <label
                  halign={Gtk.Align.START}
                  label={bind(spotify, "album")}
                  className="Album"
                  truncate
                />
              </box>
            </box>
          ) : (
            "No media playing"
          ),
        )}
      </>
    );
  };

  return (
    <window
      name={WINDOW_NAME}
      application={App}
      visible={false}
      keymode={Astal.Keymode.EXCLUSIVE}
      layer={Astal.Layer.OVERLAY}
      vexpand={true}
      anchor={Astal.WindowAnchor.BOTTOM}
      onKeyPressEvent={(self, event) => {
        if (event.get_keyval()[1] === Gdk.KEY_Escape) {
          if (self.visible) {
            self.visible = false;
          }
        }
      }}
    >
      <box className="Media base">
        <SpotifyInfo />
      </box>
    </window>
  );
}
