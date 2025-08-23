// https://github.com/PoSayDone/.dotfiles_nix/blob/main/home-manager/modules/ags/widget/Dashboard/items/Calendar/index.tsx

import { Gdk, Gtk } from "ags/gtk4";
import { getCalendarLayout } from "./Layout";
import icons from "@/constants/icons";
import { createState, For } from "ags";

const [calendarJson, setCalendarJson] = createState(
  getCalendarLayout(undefined, true),
);
let monthshift = 0;
const [monthYearLabel, setMonthYearLabel] = createState(
  `${new Date().toLocaleString("default", { month: "long" })} ${new Date().getFullYear()}`,
);

const { CENTER, START, END } = Gtk.Align;

function getDateInXMonthsTime(x: number) {
  const currentDate = new Date(); // Get the current date
  let targetMonth = currentDate.getMonth() + x; // Calculate the target month
  let targetYear = currentDate.getFullYear(); // Get the current year

  // Adjust the year and month if necessary
  targetYear += Math.floor(targetMonth / 12);
  targetMonth = ((targetMonth % 12) + 12) % 12;

  // Create a new date object with the target year and month
  const targetDate = new Date(targetYear, targetMonth, 1);

  // Set the day to the last day of the month to get the desired date
  // targetDate.setDate(0);

  return targetDate;
}

const weekDays = [
  // MONDAY IS THE FIRST DAY OF THE WEEK :HESRIGHTYOUKNOW:
  { day: "Mo", today: 0 },
  { day: "Tu", today: 0 },
  { day: "We", today: 0 },
  { day: "Th", today: 0 },
  { day: "Fr", today: 0 },
  { day: "Sa", today: 0 },
  { day: "Su", today: 0 },
];

const CalendarDay = (day: string, today: number) => {
  return (
    <button
      class={`min-w-5 min-h-6 rounded-full ${today === 1 ? "bg-primary_container" : today === -1 ? "" : ""}`}
    >
      <overlay>
        <label
          label={String(day)}
          halign={CENTER}
          class={`${today === 1 ? "text-primary" : today === -1 ? "text-surface_letiant" : ""}`}
        />
      </overlay>
    </button>
  );
};

export default () => {
  const calendarMonthYear = () => {
    return (
      <button onClicked={() => shiftCalendarXMonths(0)}>
        <label
          label={monthYearLabel}
          class="text-xl text-secondary font-bold"
        />
      </button>
    );
  };

  const shiftCalendarXMonths = (x: number) => {
    if (x === 0) monthshift = 0;
    else monthshift += x;
    let newDate: Date;
    if (monthshift === 0) newDate = new Date();
    else newDate = getDateInXMonthsTime(monthshift);

    setCalendarJson(getCalendarLayout(newDate, monthshift === 0));
    setMonthYearLabel(
      `${monthshift === 0 ? "" : "• "}${newDate.toLocaleString("default", { month: "long" })} ${newDate.getFullYear()}`,
    );
  };

  const calendarHeader = () => {
    return (
      <box spacing={8} halign={Gtk.Align.FILL}>
        {calendarMonthYear()}
        <box class="" halign={Gtk.Align.END} hexpand>
          <button onClicked={() => shiftCalendarXMonths(-1)}>
            <image iconName={icons.ui.arrow.left} />
          </button>
          <button onClicked={() => shiftCalendarXMonths(1)}>
            <image iconName={icons.ui.arrow.right} />
          </button>
        </box>
      </box>
    );
  };

  const calendarDays = () => {
    return (
      <box hexpand={true} orientation={Gtk.Orientation.VERTICAL}>
        <For each={calendarJson}>
          {(row, i) => (
            <box spacing={10}>
              {row.map((day, j) => CalendarDay(day.day, day.today))}
            </box>
          )}
        </For>
      </box>
    );
  };

  return (
    <box
      class="p-2"
      $={(self) =>
        self.connect("map", () => {
          const newDate = new Date();
          setCalendarJson(getCalendarLayout(newDate, true)); // Recalculate for the current month
          // addCalendarChildren(calendarDays, calendarJson);
          shiftCalendarXMonths(0);
        })
      }
    >
      <box halign={CENTER}>
        <box hexpand={true} orientation={Gtk.Orientation.VERTICAL} spacing={5}>
          {calendarHeader()}
          <box homogeneous={true} spacing={5}>
            {weekDays.map((day, i) => CalendarDay(day.day, day.today))}
          </box>
          {calendarDays()}
        </box>
      </box>
    </box>
  );
};
