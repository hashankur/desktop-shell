import type AstalNetwork from "gi://AstalNetwork";
import type { Accessor, Setter } from "ags";
import { Gtk } from "ags/gtk4";
import { BackButton } from "./buttons";

type StackPageProps = JSX.IntrinsicElements["box"] & {
  children?: JSX.Element;
  name: string;
  toggle?: AstalNetwork.Wifi;
  setCurrentView: Setter<string>;
};

function StackPage({ children, name, toggle, setCurrentView }: StackPageProps) {
  return (
    <box $type="named" name={name} orientation={Gtk.Orientation.VERTICAL}>
      <box spacing={10} class="mb-3">
        <BackButton name={name} setCurrentView={setCurrentView} />
        <switch
          halign={Gtk.Align.END}
          valign={Gtk.Align.CENTER}
          active={toggle?.enabled}
          // onNotifyActive={() => {
          //   // if (toggle?.enabled) {
          //   //   toggle?.set_enabled(false);
          //   // } else {
          //   toggle?.set_enabled(true);
          //   // }
          //   print(toggle?.enabled);
          // }}
        />
      </box>
      <scrolledwindow>{children}</scrolledwindow>
    </box>
  );
}

export { StackPage };
