import AstalNotifd from "gi://AstalNotifd";
import PopupWindow from "@/common/PopupWindow";
import { App, Gtk, Gdk } from "astal/gtk4";
import { bind, Variable } from "astal";
import Notification from "./Notification";

export const WINDOW_NAME = "notifications";
const notifd = AstalNotifd.get_default();

const layout = Variable("top_center")

function NotifsScrolledWindow() {
  const notifd = AstalNotifd.get_default();
  return (
    <Gtk.ScrolledWindow vexpand>
      <box vertical hexpand={false} spacing={8}>
        {bind(notifd, "notifications").as((notifs) =>
          notifs.map((e) => <Notification n={e} showActions={false} />),
        )}
        <box
          halign={Gtk.Align.CENTER}
          valign={Gtk.Align.CENTER}
          cssClasses={["not-found"]}
          vertical
          vexpand
          visible={bind(notifd, "notifications").as((n) => n.length === 0)}
        >
          <image
            iconName="notification-disabled-symbolic"
            iconSize={Gtk.IconSize.LARGE}
          />
          <label label="Your inbox is empty" />
        </box>
      </box>
    </Gtk.ScrolledWindow>
  );
}

function DNDButton() {
  return (
    <button
      tooltipText={"Do Not Disturb"}
      onClicked={() => {
        notifd.set_dont_disturb(!notifd.get_dont_disturb());
      }}
      cssClasses={bind(notifd, "dont_disturb").as((dnd) => {
        const classes = ["hover:bg-[#11151C]", "px-2", "py-1", "rounded-lg"];
        dnd && classes.push("bg-[#11151C]");
        return classes;
      })}
      label={"DND"}
    />
  );
}

function ClearButton() {
  return (
    <button
      cssClasses={["hover:bg-red-600", "p-2", "rounded-lg"]}
      onClicked={() => {
        notifd.notifications.forEach((n) => n.dismiss());
      }}
      sensitive={bind(notifd, "notifications").as((n) => n.length > 0)}
    >
      <image iconName={"user-trash-full-symbolic"} />
    </button>
  );
}

function NotificationWindow(_gdkmonitor: Gdk.Monitor) {
  return (
    <PopupWindow
      name={WINDOW_NAME}
      animation="slide top"
      layout={layout.get()}
      onDestroy={() => layout.drop()}
    >
      <box
        cssClasses={["bg-base", "m-2", "p-2", "rounded-xl", "min-w-[550px]", "min-h-[425px]"]}
        vertical
        vexpand={false}
      >
        <box cssClasses={["p-2"]} spacing={10}>
          <label label={"Notifications"} hexpand xalign={0} />
          <DNDButton />
          <ClearButton />
        </box>
        <Gtk.Separator />
        <NotifsScrolledWindow />
      </box>
    </PopupWindow>
  );
}

export default function(_gdkmonitor: Gdk.Monitor) {
  NotificationWindow(_gdkmonitor);

  layout.subscribe(() => {
    App.remove_window(App.get_window(WINDOW_NAME)!);
    NotificationWindow(_gdkmonitor);
  });
}
