//https://github.com/PoSayDone/.dotfiles_nix/blob/main/home-manager/modules/ags/widget/Dashboard/items/Todos.tsx

import icons from "@/util/icons";
import GoogleTasksService, { Task, TaskListsItem } from "@/lib/tasks";
import { ComboBox, Spinner, Ref } from "../../../common/Types";
import Pango from "gi://Pango?version=1.0";
import { Subscribable } from "astal/binding";
import { Gdk } from "ags/gtk4";
import { idle, timeout } from "ags/time";
import Gtk from "gi://Gtk?version=3.0";
import GObject from "ags/gobject";

const TARGET = [Gtk.TargetEntry.new("text/plain", Gtk.TargetFlags.SAME_APP, 0)];

const TodoItem = ({ todo }: { todo: Task }) => {
  const status = Variable(todo.status);
  const revealer: Ref<Widget.Revealer> = {};

  return (
    <revealer
      transitionDuration={300}
      transitionType={Gtk.RevealerTransitionType.SLIDE_UP}
      $={(self) => {
        idle(() => {
          self.revealChild = true;
        });
        revealer.ref = self;
        self.drag_source_set(
          Gdk.ModifierType.BUTTON1_MASK,
          TARGET,
          Gdk.DragAction.COPY,
        );
        self.connect("drag-begin", (_source, context) => {
          self.revealChild = false;
        });
      }}
    >
      <box spacing={24} hexpand={true} class="todo">
        <button
          onClicked={() => {
            status.set("completed");
            if (revealer.ref) {
              revealer.ref.revealChild = false;
              timeout(revealer.ref.transitionDuration, () => {
                GoogleTasksService.checkTask(todo);
              });
            } else {
              GoogleTasksService.checkTask(todo);
            }
          }}
        >
          <image
            class="todo__check"
            iconName={bind(status).as((s) =>
              s == "completed" ? icons.todo.checkedAlt : icons.todo.unchecked,
            )}
            pixelSize={24}
          />
        </button>

        <label
          hexpand={true}
          halign={Gtk.Align.START}
          label={todo.title}
          wrap
          wrapMode={Pango.WrapMode.CHAR}
        />
      </box>
    </revealer>
  );
};

class TodosMap implements Subscribable {
  taskService = GoogleTasksService;

  private map: Map<string, Gtk.Widget> = new Map();
  private var: Variable<Array<Gtk.Widget>> = Variable([]);

  private notify() {
    this.var.set(
      [...this.map.values()].toSorted((a, b) => a.position - b.position),
    );
  }

  constructor() {
    GoogleTasksService.connect("notify::todos", async () => {
      this.updateMap(GoogleTasksService.todos);
    });
  }

  private updateMap(tasks: Task[]) {
    const newTasksIds = new Set(tasks.map((task) => task.id));

    tasks.forEach((task) => {
      const existingTask = this.map.get(task.id);

      if (!existingTask) {
        this.map.set(
          task.id,
          Object.assign(TodoItem({ todo: task }), {
            position: parseInt(task.position),
          }),
        );
      } else existingTask.position = task.position;
    });

    for (const id of this.map.keys()) {
      if (!newTasksIds.has(id)) {
        if (this.map.has(id)) this.map.delete(id);
      }
    }

    this.notify();
  }

  get() {
    return this.var.get();
  }

  subscribe(callback: (list: Array<Gtk.Widget>) => void) {
    return this.var.subscribe(callback);
  }
}

export default () => {
  const todos = new TodosMap();
  const newTodoText = Variable<string>("");

  return (
    <box orientation={Gtk.Orientation.VERTICAL} class={"todos block"}>
      <ComboBox
        className={"todos__combobox"}
        hexpand={true}
        setup={(self) => {
          const model = new Gtk.ListStore();
          let renderer = new Gtk.CellRendererText();
          self.pack_start(renderer, true);
          self.add_attribute(renderer, "text", 1);
          GoogleTasksService.connect("notify::available-task-lists", () => {
            model.set_column_types([GObject.TYPE_STRING, GObject.TYPE_STRING]);
            GoogleTasksService.availableTaskLists.forEach(
              (list: TaskListsItem) => {
                model.set(model.append(), [0, 1], [list.id, list.title]);
              },
            );
            self.set_model(model);
          });
          GoogleTasksService.connect("notify::selected-list-id", () => {
            let selectedId = GoogleTasksService.selectedListId;
            let [success, iter] = model.get_iter_first();

            while (success) {
              let id = model.get_value(iter, 0);
              if (id === selectedId) {
                self.set_active_iter(iter);
                break;
              }
              success = model.iter_next(iter);
            }
          });
          self.connect("changed", function (entry) {
            let [success, iter] = self.get_active_iter();
            if (!success) return;
            let selectedListId = model.get_value(iter, 0); // get value
            GoogleTasksService.selectedListId = selectedListId as string;
          });
        }}
      />
      <stack
        transitionType={Gtk.StackTransitionType.CROSSFADE}
        transitionDuration={200}
        $={(self) => {
          GoogleTasksService.isLoading
            ? (self.shown = "loading")
            : (self.shown = "todos");
          self.hook(GoogleTasksService, "notify::is-loading", () => {
            GoogleTasksService.isLoading
              ? (self.shown = "loading")
              : (self.shown = "todos");
          });
        }}
      >
        <box name="todos" orientation={Gtk.Orientation.VERTICAL}>
          <box class={"todos__input_box"} spacing={24}>
            <image iconName={icons.todo.checkedAlt} />
            <entry
              hexpand
              class="todos__input"
              placeholderText={"New todo..."}
              onChanged={({ text }) => newTodoText.set(text)}
              onActivate={(self) => {
                GoogleTasksService.createTask(newTodoText.get());
                self.text = "";
              }}
            />
          </box>
          <Gtk.Scrollable class="todos__scrollable" name="todos">
            <box
              orientation={Gtk.Orientation.VERTICAL}
              class="todos__container"
              $={(self) => {
                self.drag_dest_set(
                  Gtk.DestDefaults.ALL,
                  TARGET,
                  Gdk.DragAction.COPY,
                );
                self.connect("drag-data-received", (_w, _c, _x, _y, data) => {
                  console.log("drag-data-received");
                });
              }}
            >
              {bind(todos)}
            </box>
          </Gtk.Scrollable>
        </box>
        <box hexpand vexpand halign={Gtk.Align.CENTER} name="loading">
          <Spinner
            halign={Gtk.Align.CENTER}
            widthRequest={32}
            $={(self) => self.start()}
          />
        </box>
      </stack>
    </box>
  );
};
