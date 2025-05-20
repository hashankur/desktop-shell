import Battery from "gi://AstalBattery";
import { Variable, bind, execAsync } from "astal";
import { App } from "astal/gtk4";

export function hideWindow(name: string) {
  App.get_window(name)?.set_visible(false);
}

export function notifyLowBattery() {
  const bat = Battery.get_default();
  const low = 30;
  const critical = low / 2;

  Variable.derive(
    [bind(bat, "charging"), bind(bat, "percentage")],
    (charging, percent) => {
      percent = percent * 100;

      if (!charging && (percent === low || percent === critical)) {
        execAsync([
          "notify-send",
          "--urgency=CRITICAL",
          "-i",
          "battery-empty-symbolic",
          "-a",
          "Connect Charger",
          "Battery is getting low",
        ]);
      }
    },
  );
}
