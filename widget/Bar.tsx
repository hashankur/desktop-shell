import Button from "@/common/Button";
import Window from "@/common/window";
import icons from "@/util/icons";
import { bind, Binding, GLib, Variable } from "astal";
import { App, Astal, Gtk, hook } from "astal/gtk4";
import Battery from "gi://AstalBattery";
import Mpris from "gi://AstalMpris";
import Network from "gi://AstalNetwork";
import Tray from "gi://AstalTray";
import Wp from "gi://AstalWp";

const WINDOW_NAME = "bar";

const time = Variable("").poll(1000, () => GLib.DateTime.new_now_local().format("%a %d %b | %I:%M %p")!);

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
            cssClasses={["px-3", "hover:bg-base1", "rounded-lg"]}
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

function secondsToHoursMinutes(time: number, verb: string): string {
  const seconds = Math.round(time / 60); // TODO: needs to be reactive
  return `${Math.floor(seconds / 60)}h ${Math.floor(seconds % 60)}m ${verb}`;
}

function BatteryLevel() {
  const bat = Battery.get_default();

  const batteryTooltip = Variable.derive(
    [bind(bat, "charging"), bind(bat, "timeToEmpty"), bind(bat, "timeToFull")],
    (charging, empty, full) => {
      return charging
        ? secondsToHoursMinutes(full, "to full")
        : secondsToHoursMinutes(empty, "remaining")
    })

  return (
    <box
      visible={bind(bat, "isPresent")}
      spacing={5}
      tooltipText={batteryTooltip()}
    >
      <image iconName={bind(bat, "batteryIconName")} />
      <label
        label={bind(bat, "percentage").as((p) => {
          let level = Math.floor(p * 100);
          return level === 100 ? "Full" : `${level}%`;
        })}
      />
    </box >
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
          <Button onClicked={() => spotify.play_pause()}>
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
          </Button>
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

function Left() {
  return (
    <box>
      {/* <Stats /> */}
      <Media />
    </box>
  )
}

function Center() {
  return (
    <Button
      onClicked={() => App.toggle_window("calendar")}
      halign={Gtk.Align.END}
    >
      <label label={time()} />
    </Button>
  )
}

function Right() {
  return (
    <box halign={Gtk.Align.END} spacing={5}>
      <SysTray />
      <Button
        onClicked={() => App.toggle_window("quick-settings")}
      >
        <box spacing={20}>
          <Wifi />
          <AudioLevel />
          <BatteryLevel />
        </box>
      </Button>
    </box>
  )
}

export default function Bar(monitor: number) {
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor;

  return (
    <Window
      name={WINDOW_NAME}
      monitor={monitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      layer={Astal.Layer.TOP}
      keymode={Astal.Keymode.NONE}
      anchor={TOP | LEFT | RIGHT}
      visible
    >
      <box vertical>
        {/* <box className="Workspaces"></box> */}
        <centerbox cssClasses={["px-1", "bg-background", "min-h-10"]}>
          <Left />
          <Center />
          <Right />
        </centerbox>
      </box>
    </Window>
  );
}
