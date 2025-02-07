import Window from "@/common/window";
import Brightness from "@/lib/brightness";
import icons from "@/utils/icons";
import { bind, timeout } from "astal";
import { Astal, Gtk, hook } from "astal/gtk4";
import Wp from "gi://AstalWp";

const WINDOW_NAME = "osd";
const TIMEOUT = 2000;
// BUG: artifacts remain on hide https://github.com/wmww/gtk4-layer-shell/issues/60
const TRANSITION = Gtk.RevealerTransitionType.CROSSFADE;

function BrightnessSlider() {
  const brightness = Brightness.get_default();

  return (
    <revealer
      transitionType={TRANSITION}
      setup={(self) => {
        let i = 0;

        hook(self, brightness, "notify::screen", () => {
          self.set_reveal_child(true);
          i++;
          timeout(TIMEOUT, () => {
            i--;

            if (i === 0) self.set_reveal_child(false);
          });
        });
      }}
    >
      <box cssClasses={["bg-base", "m-3", "p-2", "rounded-xl", "min-w-[50px]"]} vertical spacing={5}>
        <slider
          cssClasses={["min-h-[300px]", "min-w-[10px]", "rounded-[7px]"]}
          orientation={Gtk.Orientation.VERTICAL}
          value={bind(brightness, "screen")}
          // onDragged={({ value }) => (brightness.screen = value)}
          drawValue={false}
          inverted
        />
        <image iconName={icons.brightness.screen} cssClasses={["p-3"]} />
      </box>
    </revealer>
  );
}

function VolumeSlider() {
  const audio = Wp.get_default()?.audio.defaultSpeaker!;

  return (
    <revealer
      transitionType={TRANSITION}
      setup={(self) => {
        let i = 0;

        hook(self, bind(audio, "volume"), () => {
          self.set_reveal_child(true);
          i++;
          timeout(TIMEOUT, () => {
            i--;

            if (i === 0) self.set_reveal_child(false);
          });
        });
      }}
    >
      <box cssClasses={["bg-base", "m-3", "p-2", "rounded-xl", "min-w-[50px]"]} vertical spacing={5}>
        <slider
          cssClasses={["min-h-[300px]", "min-w-[10px]", "rounded-[7px]"]}
          orientation={Gtk.Orientation.VERTICAL}
          value={bind(audio, "volume")}
          // onDragged={({ value }) => (audio.volume = value)}
          drawValue={false}
          inverted
        />
        <image iconName={bind(audio, "volumeIcon")} cssClasses={["p-3"]} />
      </box>
    </revealer>
  );
}

export default function OSD() {
  return (
    <Window
      name={WINDOW_NAME}
      exclusivity={Astal.Exclusivity.IGNORE}
      anchor={Astal.WindowAnchor.RIGHT}
      keymode={Astal.Keymode.NONE}
      visible
    >
      <box>
        <BrightnessSlider />
        <VolumeSlider />
      </box>
    </Window>
  );
}
