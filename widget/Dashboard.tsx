import { App, Astal, Gdk, Gtk } from "astal/gtk3";
import { bind } from "astal";
import Mpris from "gi://AstalMpris"

const WINDOW_NAME = "dashboard"

export default function Dashboard() {
  const SpotifyInfo = () => {
    const spotify = Mpris.Player.new("spotify")

    return (
      <box className="Media">
        {bind(spotify, "available").as(available => available ? (
          <box>
            <box
              className="Cover"
              valign={Gtk.Align.CENTER}
              css={bind(spotify, "coverArt").as(cover => `background-image: url('${cover}');`)}
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
        ) : "No media playing"
        )}
      </box>
    )
  }

  return (
    <window
      name={WINDOW_NAME}
      application={App}
      visible={false}
      className="Dashboard"
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
      <box className="Dashboard-Base" vertical>
        <box className="Dashboard-Container" vertical>
          <SpotifyInfo />
        </box>
      </box>
    </window>
  );
}
