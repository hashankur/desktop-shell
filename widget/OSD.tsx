import Window from "@/widget/common/window";
import Brightness from "@/lib/brightness";
import icons from "@/constants/icons";
import type { Accessor } from "ags";
import { createBinding } from "ags";
import { Astal, Gtk } from "ags/gtk4";
import { timeout } from "ags/time";
import Wp from "gi://AstalWp";

const WINDOW_NAME = "osd";
const TIMEOUT = 2000;
// BUG: artifacts remain on hide https://github.com/wmww/gtk4-layer-shell/issues/60
const TRANSITION = Gtk.RevealerTransitionType.SLIDE_LEFT;

function createSlider(
  toggle: (visibility: () => void) => void,
  iconName: string | Accessor<string>,
  value: Accessor<number>,
  onDragged = null,
) {
  return (
    <revealer
      transitionType={TRANSITION}
      $={(self) => {
        let i = 0;
        const setVisibility = () => {
          self.set_reveal_child(true);
          self.set_opacity(1);

          i++;
          timeout(TIMEOUT, () => {
            i--;
            if (i === 0) {
              self.set_reveal_child(false);
              self.set_opacity(0.1); // 1px artifact workaround
            }
          });
        };

        toggle(setVisibility);
      }}
    >
      <box
        class="bg-surface p-2 rounded-xl"
        orientation={Gtk.Orientation.VERTICAL}
        spacing={5}
      >
        <slider
          class="min-h-[300px] *:min-w-[25px] rounded-[7px] unset"
          orientation={Gtk.Orientation.VERTICAL}
          value={value}
          drawValue={false}
          inverted
        />
        <image iconName={iconName} cssClasses={["p-3"]} />
      </box>
    </revealer>
  );
}

function BrightnessSlider() {
  const brightness = Brightness.get_default();

  return createSlider(
    (set) => {
      brightness?.connect("notify::screen", set);
    },
    icons.brightness.screen,
    createBinding(brightness, "screen"),
    null, // onDragged can be added here if needed
  );
}

function VolumeSlider() {
  const audio = Wp.get_default()?.audio.defaultSpeaker!;

  return createSlider(
    (visibility) => {
      audio?.connect("notify::volume", visibility);
      audio?.connect("notify::mute", visibility);
    },
    createBinding(audio, "volumeIcon"),
    createBinding(audio, "volume"),
    null, // onDragged can be added here if needed
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
      defaultWidth={-1}
      margin={10}
    >
      <box class="bg-transparent">
        <BrightnessSlider />
        <VolumeSlider />
      </box>
    </Window>
  );
}
