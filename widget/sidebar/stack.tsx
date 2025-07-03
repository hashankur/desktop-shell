import { Gtk } from "ags/gtk4";
import { BackButton } from "./buttons";
import type { Accessor } from "ags";

type StackPageProps = {
  child?: JSX.Element;
  name: string;
  toggle?: any;
  currentView: Accessor<string>;
};

function StackPage({ child, name, toggle, currentView }: StackPageProps) {
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
