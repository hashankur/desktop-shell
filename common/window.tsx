import app from "ags/gtk4/app";
import Astal from "gi://Astal";

type ButtonProps = JSX.IntrinsicElements["window"] & {
  children: JSX.Element | Array<JSX.Element>;
  name?: string;
};

export default function Window({
  children,
  visible = false,
  keymode = Astal.Keymode.EXCLUSIVE,
  name,
  ...props
}: ButtonProps) {
  return (
    <window
      application={app}
      visible={visible}
      keymode={keymode}
      name={name}
      layer={Astal.Layer.OVERLAY}
      margin={10}
      // onKeyPressed={(_, keyval) => {
      //   if (keyval === Gdk.KEY_Escape) {
      //     name && App.toggle_window(name);
      //   }
      // }}
      class="bg-transparent"
      defaultHeight={-1}
      {...props}
    >
      {children}
    </window>
  );
}
