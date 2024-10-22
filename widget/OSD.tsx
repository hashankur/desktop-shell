import { App, Astal, Gdk, Gtk } from "astal/gtk3";
import { bind, timeout } from "astal";
import Brightness from "../lib/brightness";

const WINDOW_NAME = "osd";

function BrightnessSlider() {
  const brightness = Brightness.get_default();

  return (
    <revealer
      transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
      transitionDuration={125}
      setup={(self) => {
        let i = 0;

        self.hook(brightness, "notify::screen", () => {
          self.set_reveal_child(true);
          i++;
          timeout(1000, () => {
            i--;

            if (i === 0) self.set_reveal_child(false);
          });
        });
      }}
    >
      <box className="Osd-Base" vertical>
        <slider
          className="Osd-Slider"
          vertical
          value={bind(brightness, "screen")}
          onDragged={({ value }) => (brightness.screen = value)}
          drawValue={false}
          inverted
        />
        <icon icon="display-brightness-symbolic" />
      </box>
    </revealer>
  );
}

export default function OSD() {
  return (
    <window
      name={WINDOW_NAME}
      application={App}
      className="Osd"
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.OVERLAY}
      anchor={Astal.WindowAnchor.RIGHT}
    >
      <box vertical>
        <BrightnessSlider />
      </box>
    </window>
  );
}
