import { App, Astal, Gdk, Gtk } from "astal/gtk3";
import { bind, timeout } from "astal";
import Mpris from "gi://AstalMpris";

const WINDOW_NAME = "media";

export default function Dashboard() {
  const SpotifyInfo = () => {
    const spotify = Mpris.Player.new("spotify");

    return (
      <>
        {bind(spotify, "available").as((available) =>
          available ? (
            <box>
              <box
                className="Cover"
                valign={Gtk.Align.CENTER}
                css={bind(spotify, "coverArt").as(
                  (cover) => `background-image: url('${cover}');`,
                )}
              />
              <box vertical className="Player" valign={Gtk.Align.CENTER}>
                <label
                  halign={Gtk.Align.START}
                  label={bind(spotify, "title")}
                  className="Title"
                />
                <label
                  halign={Gtk.Align.START}
                  label={bind(spotify, "artist")}
                  className="Artist"
                />
                <label
                  halign={Gtk.Align.START}
                  label={bind(spotify, "album")}
                  className="Album"
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
      // exclusivity={Astal.Exclusivity.NORMAL}
      layer={Astal.Layer.OVERLAY}
      vexpand={true}
      anchor={
        Astal.WindowAnchor.BOTTOM |
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.RIGHT
      }
      onKeyPressEvent={(self, event) => {
        if (event.get_keyval()[1] === Gdk.KEY_Escape) {
          if (self.visible) {
            self.visible = false;
          }
        }
      }}
    >
      <box className="Media base">
        <box className="Media-Container" vertical>
          <SpotifyInfo />
        </box>
      </box>
    </window>
  );
}
