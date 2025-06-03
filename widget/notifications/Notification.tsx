import { Gtk } from "astal/gtk4";
import { GLib } from "astal";
import Pango from "gi://Pango";
import AstalNotifd from "gi://AstalNotifd";
import icons from "@/util/icons";

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
  n,
  showActions = true,
}: {
  n: AstalNotifd.Notification;
  showActions?: boolean;
}) {
  return (
    <box
      name={n.id.toString()}
      cssClasses={[
        "p-3",
        "rounded-xl",
        "min-w-[435px]",
        "min-h-[10px]",
        urgency(n),
      ]}
      vertical
    >
      <box cssClasses={["pb-1"]} spacing={15}>
        {n.image && fileExists(n.image) ? (
          <image
            file={n.image}
            overflow={Gtk.Overflow.HIDDEN}
            valign={Gtk.Align.CENTER}
            cssClasses={["icon-2xl", "rounded-full"]}
          />
        ) : (
          (n.appIcon || n.desktopEntry) && (
            <image
              iconName={n.appIcon || n.desktopEntry}
              valign={Gtk.Align.CENTER}
              cssClasses={["icon-2xl", "rounded-full"]}
            />
          )
        )}
        <box vertical>
          <box spacing={10}>
            <label
              cssClasses={[
                "text-on_surface_variant",
                "font-medium",
                "text-[14px]",
              ]}
              halign={Gtk.Align.START}
              label={n.appName || "Unknown"}
            />
            <label
              cssClasses={[
                "text-on_surface_variant",
                "font-medium",
                "text-[14px]",
              ]}
              hexpand
              halign={Gtk.Align.END}
              label={time(n.time) ?? ""}
            />
            <button
              onClicked={() => n.dismiss()}
              cssClasses={[
                "rounded-full",
                "min-w-2",
                "min-h-2",
                "p-2",
                "bg-surface_container_highest/50",
                "hover:bg-on_error",
                "hover:text-error",
              ]}
            >
              <image iconName={icons.ui.close} />
            </button>
          </box>
          <label
            ellipsize={Pango.EllipsizeMode.END}
            maxWidthChars={30}
            cssClasses={["text-xl", "mb-1", "font-bold"]}
            halign={Gtk.Align.START}
            xalign={0}
            label={n.summary}
          />
          {n.body && (
            <label
              cssClasses={["text-[15px]"]}
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
  );
}
