import { Gdk, Gtk } from "ags/gtk4";
import app from "ags/gtk4/app";
import Astal from "gi://Astal";
import Graphene from "gi://Graphene";

type WindowProps = JSX.IntrinsicElements["window"] & {
  name?: string;
  closeOnEscape?: boolean;
  closeOnClickaway?: boolean;
};

export default function Window({
  children,
  visible = false,
  keymode = Astal.Keymode.EXCLUSIVE,
  closeOnEscape = true,
  closeOnClickaway = true,
  ...props
}: WindowProps) {
  let windowRef: Astal.Window;
  let contentElement: Gtk.Widget;

  function onKey(
    _e: Gtk.EventControllerKey,
    keyval: number,
    _: number,
    mod: number,
  ) {
    if (closeOnEscape && keyval === Gdk.KEY_Escape && windowRef) {
      windowRef.visible = false;
    }
  }

  function onClick(_e: Gtk.GestureClick, _: number, x: number, y: number) {
    if (!closeOnClickaway || !contentElement || !windowRef) return;

    const [, rect] = contentElement.compute_bounds(windowRef);
    const position = new Graphene.Point({ x, y });

    if (!rect.contains_point(position)) {
      windowRef.visible = false;
      return true;
    }
  }

  return (
    <window
      application={app}
      layer={Astal.Layer.OVERLAY}
      margin={20}
      class="bg-transparent"
      defaultHeight={-1}
      visible={visible}
      keymode={keymode}
      $={(ref) => {
        windowRef = ref;
      }}
      {...props}
    >
      <Gtk.EventControllerKey onKeyPressed={onKey} />
      <Gtk.GestureClick onPressed={onClick} />
      <box
        $={(ref) => {
          contentElement = ref;
        }}
      >
        {children}
      </box>
    </window>
  );
}
