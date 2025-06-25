import { createBinding, createComputed } from "ags";
import app from "ags/gtk4/app";
import { execAsync } from "ags/process";
import Battery from "gi://AstalBattery";

function hideWindow(name: string) {
  app.get_window(name)?.set_visible(false);
}

function notifyLowBattery() {
  const bat = Battery.get_default();
  const low = 30;
  const critical = low / 2;

  createComputed(
    [createBinding(bat, "charging"), createBinding(bat, "percentage")],
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

export default { hideWindow, notifyLowBattery };
