import Window from "@/common/window";
import icons from "@/utils/icons";
import { bind, Variable } from "astal";
import { App, Astal, Gtk, hook } from "astal/gtk4";
import Battery from "gi://AstalBattery";
import Mpris from "gi://AstalMpris";
import Network from "gi://AstalNetwork";
import Tray from "gi://AstalTray";
import Wp from "gi://AstalWp";

const WINDOW_NAME = "bar";

const time = Variable("").poll(1000, "date '+%a %d %b | %I:%M %p'");

// WIP - Mostly works
function SysTray() {
  const tray = Tray.get_default();

  return (
    <box spacing={10}>
      {bind(tray, "items").as((items) =>
        items.map((item) => (
          <menubutton
            tooltipMarkup={bind(item, "tooltipMarkup")}
            menuModel={bind(item, "menuModel")}
            setup={self => hook(self, item, 'notify::action-group', () => self.insert_action_group('dbusmenu', item.action_group))}
          >
            <image gicon={bind(item, "gicon")} />
          </menubutton>
        )),
      )}
    </box>
  );
}

function Wifi() {
  const { wifi } = Network.get_default();

  return (
    <image
      tooltipText={bind(wifi, "ssid").as(String)}
      iconName={bind(wifi, "iconName")}
    />
  );
}

function AudioLevel() {
  const speaker = Wp.get_default()?.audio.defaultSpeaker!;

  return <image iconName={bind(speaker, "volumeIcon")} />;
}

function secondsToHoursMinutes(time: number, verb: string) {
  time = Math.round(time / 60);
  return `${Math.floor(time / 60)}h ${Math.floor(time % 60)}m ${verb}`;
}

function BatteryLevel() {
  const bat = Battery.get_default();

  return (
    <box
      visible={bind(bat, "isPresent")}
      spacing={5}
      tooltipText={
        bind(bat, "charging")
          ? bind(bat, "timeToFull").as((val) =>
            secondsToHoursMinutes(val, "until full"),
          )
          : bind(bat, "timeToEmpty").as((val) =>
            secondsToHoursMinutes(val, "remaining"),
          )
      }
    >
      <image iconName={bind(bat, "batteryIconName")} />
      <label
        label={bind(bat, "percentage").as((p) => {
          let level = Math.floor(p * 100);
          return level === 100 ? "Full" : `${level}%`;
        })}
      />
    </box>
  );
}

function Media() {
  const spotify = Mpris.Player.new("spotify");

  const formattedLabel = Variable.derive(
    [bind(spotify, "artist"), bind(spotify, "title")],
    (artist: String, title: String) => artist + " - " + title,
  );

  return (
    <>
      {bind(spotify, "available").as((available) =>
        available ? (
          <button onClicked={() => spotify.play_pause()}>
            <box spacing={5}>
              <image
                iconName={bind(spotify, "playbackStatus").as((status) =>
                  status === Mpris.PlaybackStatus.PLAYING
                    ? icons.media.playing
                    : icons.media.stopped,
                )}
              />
              <label label={formattedLabel()} />
            </box>
          </button>
        ) : (
          ""
        ),
      )}
    </>
  );
}

function Stats() {
  const cpu = Variable(0).poll(5000, [
    "sh",
    "-c",
    "top -bn1 | grep Cpu | sed 's/\\,/\\./g' | awk '{print $2}'",
  ]);
  const memory = Variable(0).poll(5000, [
    "sh",
    "-c",
    `free | awk '/^Mem/ {printf("%.2f\\n", ($3/$2) * 100)}'`,
  ]);
  const gpu = Variable(0).poll(
    5000,
    "cat /sys/class/hwmon/hwmon6/device/gpu_busy_percent",
  );
  const temp = Variable(0).poll(
    5000,
    "cat /sys/class/thermal/thermal_zone0/temp",
  );

  const Stats = ({ value, tooltip }) => {
    return (
      <circularprogress
        value={value}
        startAt={0.75}
        endAt={0.75}
        tooltipText={tooltip}
        cssName="Stats"
        rounded
      />
    );
  };

  return (
    <box css="padding: 12px 0; margin-right: 20px;" spacing={10}>
      <Stats
        value={cpu((val) => val / 100)}
        tooltip={cpu((val) => `CPU: ${Math.round(val)}% used`)}
      />
      <Stats
        value={memory((val) => val / 100)}
        tooltip={memory((val) => `Memory: ${Math.round(val)}% used`)}
      />
      <Stats
        value={gpu((val) => val / 100)}
        tooltip={gpu((val) => `GPU: ${Math.round(val)}% used`)}
      />
      <Stats
        value={temp((val) => val / 1000 / 100)}
        tooltip={temp((val) => `${val / 1000} °C`)}
      />
    </box>
  );
}

export default function Bar(monitor: number) {
  return (
    <Window
      name={WINDOW_NAME}
      monitor={monitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      layer={Astal.Layer.TOP}
      keymode={Astal.Keymode.NONE}
      anchor={
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.RIGHT
      }
      visible
    >
      <box vertical>
        {/* <box className="Workspaces"></box> */}
        <centerbox cssClasses={["px-4", "bg-base", "min-h-10"]}>
          {/* Left */}
          <box>
            {/* <Stats /> */}
            <Media />
          </box>

          {/* Center */}
          <button
            onClicked={() => App.toggle_window("calendar")}
            halign={Gtk.Align.END}
          >
            <label label={time()} />
          </button>

          {/* Right */}
          <box halign={Gtk.Align.END} spacing={20}>
            <SysTray />
            <button
            // onClick={() => App.toggle_window("quick-settings")}
            >
              <box spacing={20}>
                <Wifi />
                <AudioLevel />
              </box>
            </button>

            <BatteryLevel />
          </box>
        </centerbox>
      </box>
    </Window>
  );
}
