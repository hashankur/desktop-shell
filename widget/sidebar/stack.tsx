import { Gtk } from "astal/gtk4";
import { BackButton } from "./buttons";
import { type Variable } from "astal";

type StackPage = {
  child?: JSX.Element;
  name: string;
  toggle?: any;
  currentView: Variable<string>;
};

function StackPage({ child, name, toggle, currentView }: StackPage) {
  return (
    <box name={name} vertical>
      <box spacing={10} cssClasses={["mb-3"]}>
        <BackButton name={name} currentView={currentView} />
        <switch
          halign={Gtk.Align.END}
          valign={Gtk.Align.CENTER}
          active={toggle?.enabled}
          onNotifyActive={() => {
            // if (toggle?.enabled) {
            //   toggle?.set_enabled(false);
            // } else {
            toggle?.set_enabled(true);
            // }
            print(toggle?.enabled);
          }}
        />
      </box>
      <Gtk.ScrolledWindow vexpand>{child}</Gtk.ScrolledWindow>
    </box>
  );
}

export { StackPage };
