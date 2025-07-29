import { getTimeTooltip, useRelativeTime } from "@/lib/time";
import icons from "@/util/icons";
import { Gtk } from "ags/gtk4";
import Adw from "gi://Adw";
import AstalNotifd from "gi://AstalNotifd";
import GLib from "gi://GLib";
import Pango from "gi://Pango";

const fileExists = (path: string): boolean =>
  GLib.file_test(path, GLib.FileTest.EXISTS);

const getUrgencyClass = (notification: AstalNotifd.Notification): string => {
  const { CRITICAL } = AstalNotifd.Urgency;
  return notification.urgency === CRITICAL
    ? "bg-on_error"
    : "bg-surface_container_low";
};

const NotificationIcon = ({
  notification,
}: {
  notification: AstalNotifd.Notification;
}) => {
  if (notification.image && fileExists(notification.image)) {
    return (
      <image
        file={notification.image}
        overflow={Gtk.Overflow.HIDDEN}
        valign={Gtk.Align.CENTER}
        class="icon-2xl rounded-full"
      />
    );
  }

  if (notification.appIcon || notification.desktopEntry) {
    return (
      <image
        iconName={notification.appIcon || notification.desktopEntry}
        valign={Gtk.Align.CENTER}
        class="icon-2xl rounded-full"
      />
    );
  }

  return <></>;
};

const NotificationHeader = ({
  notification,
}: {
  notification: AstalNotifd.Notification;
}) => (
  <box spacing={10}>
    <label
      class="text-on_surface_variant font-medium text-sm"
      halign={Gtk.Align.START}
      label={notification.appName || "Unknown"}
    />
    <label
      class="text-on_surface_variant font-medium text-sm"
      hexpand
      halign={Gtk.Align.END}
      label={useRelativeTime(notification.time)}
      tooltipText={getTimeTooltip(notification.time)}
    />
    <button
      onClicked={() => notification.dismiss()}
      class="rounded-full min-w-1.5 min-h-1.5 p-1.5 bg-surface_container_highest/50 hover:bg-on_error hover:text-error"
    >
      <image iconName={icons.ui.close} />
    </button>
  </box>
);

const NotificationContent = ({
  notification,
}: {
  notification: AstalNotifd.Notification;
}) => (
  <box orientation={Gtk.Orientation.VERTICAL}>
    <NotificationHeader notification={notification} />
    <label
      class="text-lg font-extrabold"
      maxWidthChars={30}
      wrap
      halign={Gtk.Align.START}
      xalign={0}
      label={notification.summary}
      tooltipMarkup={notification.summary}
      ellipsize={Pango.EllipsizeMode.END}
    />
    {notification.body && (
      <label
        class="text-sm"
        maxWidthChars={30}
        wrap
        halign={Gtk.Align.START}
        xalign={0}
        label={notification.body}
        tooltipMarkup={notification.body}
        ellipsize={Pango.EllipsizeMode.END}
      />
    )}
  </box>
);

type NotificationProps = JSX.IntrinsicElements["box"] & {
  notification: AstalNotifd.Notification;
  onHoverLost?: () => void;
};

export default function Notification({
  notification,
  onHoverLost,
  ...props
}: NotificationProps) {
  return (
    <Adw.Clamp maximumSize={450}>
      <box
        widthRequest={450}
        name={notification.id.toString()}
        cssClasses={[
          "p-3",
          "rounded-xl",
          "min-h-[10px]",
          getUrgencyClass(notification),
        ]}
        orientation={Gtk.Orientation.VERTICAL}
        {...props}
      >
        <Gtk.EventControllerMotion onLeave={onHoverLost} />
        <box spacing={15}>
          <NotificationIcon notification={notification} />
          <NotificationContent notification={notification} />
        </box>
      </box>
    </Adw.Clamp>
  );
}
