import Window from "@/common/window";
import icons from "@/util/icons";
import app from "ags/gtk4/app";
import { exec } from "ags/process";

const WINDOW_NAME = "power-menu";

const options = [
  {
    name: "Shutdown",
    icon: icons.powermenu.shutdown,
    command: "systemctl poweroff",
  },
  {
    name: "Reboot",
    icon: icons.powermenu.reboot,
    command: "systemctl reboot",
  },
  {
    name: "Suspend",
    icon: icons.powermenu.sleep,
    command: "systemctl suspend",
  },
];

export default function PowerMenu() {
  return (
    <Window name={WINDOW_NAME}>
      <box class="bg-surface rounded-xl p-3" spacing={10}>
        {options.map((option) => (
          <button
            onClicked={() => {
              app.toggle_window(WINDOW_NAME);
              exec(option.command);
            }}
            class="rounded-lg bg-primary_container hover:bg-on_primary transition"
          >
            <image
              class="min-w-32 min-h-32 icon-xl text-on_primary_container"
              iconName={option.icon}
            />
          </button>
        ))}
      </box>
    </Window>
  );
}
