import type { Gtk } from "ags/gtk4";
import app from "ags/gtk4/app";
import Astal from "gi://Astal";
import Gdk from "gi://Gdk";

type Props = Gtk.Window & {
  children: JSX.Element | Array<JSX.Element>;
  name?: string;
};

export default function Window({
  children,
  visible = false,
  // keymode = Astal.Keymode.EXCLUSIVE,
  name,
  ...props
}: Props) {
  return (
    <window
      application={app}
      visible={visible}
      // keymode={keymode}
      name={name}
      layer={Astal.Layer.OVERLAY}
      margin={10}
      // onKeyPressed={(_, keyval) => {
      //   if (keyval === Gdk.KEY_Escape) {
      //     name && App.toggle_window(name);
      //   }
      // }}
      cssClasses={["bg-transparent"]}
      {...props}
    >
      {children}
    </window>
  );
}
