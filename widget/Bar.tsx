import icons from "@/utils/icons";
import { bind, exec, Variable } from "astal";
import { App, Astal, Gdk, Gtk } from "astal/gtk3";
import Mpris from "gi://AstalMpris";
import Battery from "gi://AstalBattery";
import Wp from "gi://AstalWp";
import Network from "gi://AstalNetwork";
import Tray from "gi://AstalTray";

const WINDOW_NAME = "bar";

const time = Variable("").poll(1000, "date '+%a %d %b | %I:%M %p'");

function SysTray() {
  const tray = Tray.get_default();

  return (
    <box>
      {bind(tray, "items").as((items) =>
        items.map((item) => {
          if (item.iconThemePath) App.add_icons(item.iconThemePath);

          const menu = item.create_menu();

          return (
            <button
              className="BarBtn"
              tooltipMarkup={bind(item, "tooltipMarkup")}
              onDestroy={() => menu?.destroy()}
              onClickRelease={(self) => {
                menu?.popup_at_widget(
                  self,
                  Gdk.Gravity.SOUTH,
                  Gdk.Gravity.NORTH,
                  null,
                );
              }}
            >
              <icon gIcon={bind(item, "gicon")} />
            </button>
          );
        }),
      )}
    </box>
  );
}

function Wifi() {
  const { wifi } = Network.get_default();

  return (
    <icon
      tooltipText={bind(wifi, "ssid").as(String)}
      className="Wifi"
      icon={bind(wifi, "iconName")}
    />
  );
}

function AudioLevel() {
  const speaker = Wp.get_default()?.audio.defaultSpeaker!;

  return <icon icon={bind(speaker, "volumeIcon")} />;
}

function BatteryLevel() {
  const bat = Battery.get_default();

  return (
    <box className="Battery" visible={bind(bat, "isPresent")}>
      <icon className="IconLabel" icon={bind(bat, "batteryIconName")} />
      <label
        css="font-size: 13px;"
        label={bind(bat, "percentage").as((p) => {
          let level = Math.floor(p * 100);
          return level === 100 ? "Full" : `${level} %`;
        })}
      />
    </box>
  );
}

function Media() {
  const spotify = Mpris.Player.new("spotify");

  return (
    <box className="Media">
      {bind(spotify, "available").as((available) =>
        available ? (
          <>
            <icon
              className="IconLabel"
              icon={bind(spotify, "playbackStatus").as((status) =>
                status === Mpris.PlaybackStatus.PLAYING
                  ? icons.media.playing
                  : icons.media.stopped,
              )}
            />
            <button className="BarBtn" onClick={() => spotify.play_pause()}>
              <label
                label={bind(spotify, "title").as(
                  () => `${spotify.artist} - ${spotify.title}`,
                )}
              />
            </button>
          </>
        ) : (
          "Nothing Playing"
        ),
      )}
    </box>
  );
}

export default function Bar(monitor: number) {
  return (
    <window
      name={WINDOW_NAME}
      monitor={monitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.RIGHT
      }
      application={App}
    >
      <box vertical>
        {/* <box className="Workspaces"></box> */}
        <centerbox className="Bar">
          <box>
            <Media />
          </box>
          <button
            className="BarBtn"
            // onClick={() => exec("gnome-calendar")}
            onClick={() => App.toggle_window("dashboard")}
            halign={Gtk.Align.END}
          >
            <label label={time()} />
          </button>
          <box halign={Gtk.Align.END} spacing={20}>
            <SysTray />
            <Wifi />
            <AudioLevel />
            <BatteryLevel />
          </box>
        </centerbox>
      </box>
    </window>
  );
}
