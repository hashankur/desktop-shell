import Pango from "gi://Pango";
import AstalNotifd from "gi://AstalNotifd";
import icons from "@/util/icons";
import GLib from "gi://GLib";
import { Gtk } from "ags/gtk4";
import Adw from "gi://Adw";

const time = (time: number, format = "%I:%M %p") =>
  GLib.DateTime.new_from_unix_local(time).format(format);

const fileExists = (path: string) => GLib.file_test(path, GLib.FileTest.EXISTS);

const urgency = (n: AstalNotifd.Notification) => {
  const { CRITICAL } = AstalNotifd.Urgency;

  switch (n.urgency) {
    case CRITICAL:
      return "bg-on_error";
    default:
      return "bg-surface_container_low";
  }
};

export default function Notification({
  notification: n,
  onHoverLost,
  ...props
}: {
  notification: AstalNotifd.Notification;
  onHoverLost?: () => void;
}) {
  return (
    <Adw.Clamp maximumSize={450}>
      <box
        widthRequest={450}
        name={n.id.toString()}
        cssClasses={["p-3", "rounded-xl", "min-h-[10px]", urgency(n)]}
        orientation={Gtk.Orientation.VERTICAL}
        {...props}
      >
        <Gtk.EventControllerMotion onLeave={onHoverLost} />
        <box spacing={15}>
          {n.image && fileExists(n.image) ? (
            <image
              file={n.image}
              overflow={Gtk.Overflow.HIDDEN}
              valign={Gtk.Align.CENTER}
              class="icon-2xl rounded-full"
            />
          ) : (
            (n.appIcon || n.desktopEntry) && (
              <image
                iconName={n.appIcon || n.desktopEntry}
                valign={Gtk.Align.CENTER}
                class="icon-2xl rounded-full"
              />
            )
          )}
          <box orientation={Gtk.Orientation.VERTICAL}>
            <box spacing={10}>
              <label
                class="text-on_surface_variant font-medium text-sm"
                halign={Gtk.Align.START}
                label={n.appName || "Unknown"}
              />
              <label
                class="text-on_surface_variant font-medium text-sm"
                hexpand
                halign={Gtk.Align.END}
                label={time(n.time) ?? ""}
              />
              <button
                onClicked={() => n.dismiss()}
                class="rounded-full min-w-1.5 min-h-1.5 p-1.5 bg-surface_container_highest/50 hover:bg-on_error hover:text-error"
              >
                <image iconName={icons.ui.close} />
              </button>
            </box>
            <label
              class="text-lg font-extrabold"
              maxWidthChars={30}
              wrap
              halign={Gtk.Align.START}
              xalign={0}
              label={n.summary}
              tooltipMarkup={n.summary}
              ellipsize={Pango.EllipsizeMode.END}
            />
            {n.body && (
              <label
                class="text-sm"
                maxWidthChars={30}
                wrap
                halign={Gtk.Align.START}
                xalign={0}
                label={n.body}
                tooltipMarkup={n.body}
                ellipsize={Pango.EllipsizeMode.END}
              />
            )}
          </box>
        </box>
      </box>
    </Adw.Clamp>
  );
}
