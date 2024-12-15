import { App } from "astal/gtk3";
import Astal from "gi://Astal?version=3.0";
import Gdk from "gi://Gdk?version=3.0";

type Props = {
  child?: JSX.Element; // when only one child is passed
  children?: Array<JSX.Element>; // when multiple children are passed
  name: string;
  visible?: boolean;
  monitor?: number;
  anchor?: Astal.WindowAnchor;
  exclusivity?: Astal.Exclusivity;
  keymode?: Astal.Keymode;
  setup?(self: any): void;
};

export default function Window({
  children,
  visible = false,
  keymode = Astal.Keymode.EXCLUSIVE,
  ...props
}: Props) {
  return (
    <window
      application={App}
      visible={visible}
      keymode={keymode}
      layer={Astal.Layer.OVERLAY}
      {...props}
      onKeyPressEvent={(self, event) => {
        if (event.get_keyval()[1] === Gdk.KEY_Escape) {
          self.hide();
        }
      }}
    >
      {children}
    </window>
  );
}
