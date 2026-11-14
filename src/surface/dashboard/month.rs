use amane::{Center, Color, Column, Parent, Rectangle, Row, Service, Text, Weight, Widget};

use super::browse;
use super::parts::{icon_button, line, small, spacer, text_button};
use crate::calendar::Calendar;
use crate::calendar::days::{GRID_DAYS, grid_start, per_day};
use crate::clock::{Clock, civil_date, month_name};
use crate::hover;
use crate::tasks::Tasks;
use crate::theme::{MONO, SANS, Theme, dash, faded, space};

const HEADER: [&str; 7] = ["mo", "tu", "we", "th", "fr", "sa", "su"];

/*
 * a month as six weeks under the weekday names, monday first, with the
 * days around it from the months either side. a dot under a day for each
 * thing on it, up to three, and a ring beside them when a task is due.
 * today is the one filled circle. its name sits
 * over it with arrows to move a month either way, and a way back to this
 * month once it has moved
 */
pub fn view(theme: &Theme, monitor: &str, width: f32) -> Column {
    let (year, month) = browse::shown();

    let clock = Clock::read();
    let (today, offset) = (clock.days(), clock.offset());
    drop(clock);

    let first = grid_start(year, month);

    let calendar = Calendar::read();
    let counts = if calendar.signed_in() {
        per_day(calendar.month(year, month), first, GRID_DAYS, offset)
    } else {
        Vec::new()
    };
    drop(calendar);

    // the days in the grid with an open task due
    let tasks = Tasks::read();
    let due_days: Vec<i64> = if tasks.ready() {
        tasks
            .tasks()
            .iter()
            .filter(|task| !task.done)
            .filter_map(|task| task.due)
            .filter(|day| (first..first + GRID_DAYS).contains(day))
            .collect()
    } else {
        Vec::new()
    };
    drop(tasks);

    let cell_width = width / 7.0;

    let names: Vec<Box<dyn Widget>> = HEADER
        .iter()
        .map(|name| cell(small(*name, theme.outline), cell_width, line(dash::SMALL)))
        .collect();

    let mut rows: Vec<Box<dyn Widget>> = vec![
        Box::new(header(theme, monitor, year, month, width)),
        Box::new(spacer(space::MD)),
        Box::new(Row::new(names)),
    ];

    for week in 0..6 {
        let days: Vec<Box<dyn Widget>> = (0..7)
            .map(|weekday| {
                let index = week * 7 + weekday;
                let day = first + index as i64;
                let (_, day_month, date) = civil_date(day);

                let place = Place {
                    today: day == today,
                    outside: day_month != month,
                    weekend: weekday >= 5,
                };

                let count = counts.get(index).copied().unwrap_or(0);
                let due = due_days.contains(&day);

                cell(number(date, count, due, place, theme), cell_width, dash::CELL)
            })
            .collect();

        rows.push(Box::new(Row::new(days)));
    }

    Column::new(rows).width(width)
}

// where a day falls, which picks its colours
#[derive(Clone, Copy)]
struct Place {
    today: bool,
    outside: bool,
    weekend: bool,
}

// the month's name and year, then the way back to today and the arrows, against the right edge
fn header(theme: &Theme, monitor: &str, year: i64, month: i64, width: f32) -> Row {
    let heading = |text: String, color: Color| {
        Text::new(text).font(SANS).size(dash::HEADING).color(color)
    };

    let mut items: Vec<Box<dyn Widget>> = vec![
        Box::new(heading(month_name(month).to_string(), theme.on_surface)),
        Box::new(heading(year.to_string(), theme.outline)),
        Box::new(Rectangle::new().width(Parent).height(line(dash::HEADING))),
    ];

    if !browse::at_today() {
        let key = hover::key(monitor, "dash/month/today");

        items.push(Box::new(text_button("today", key, theme, |_| browse::today())));
    }

    let arrows = [("pan-start", "dash/month/back", -1), ("pan-end", "dash/month/on", 1)];

    for (icon, item, by) in arrows {
        let key = hover::key(monitor, item);

        let arrow = icon_button(icon, dash::ARROW, key, theme.on_surface_variant, theme, move |_| {
            browse::step(by)
        });

        if let Some(arrow) = arrow {
            items.push(Box::new(arrow));
        }
    }

    Row::new(items).width(width).gap(space::SM).align(Center)
}

// a day's number, with today's circle behind it, over its dots and its ring
fn number(date: i64, count: usize, due: bool, place: Place, theme: &Theme) -> Column {
    let color = if place.today {
        theme.on_primary
    } else if place.outside {
        theme.outline_variant
    } else if place.weekend {
        theme.outline
    } else {
        theme.on_surface_variant
    };

    let text = Text::new(date.to_string())
        .font(MONO)
        .size(dash::BODY)
        .color(color)
        .weight(if place.today { Weight::Bold } else { Weight::Regular });

    let mark = Rectangle::new()
        .width(dash::MARK)
        .height(dash::MARK)
        .radius(dash::MARK / 2.0)
        .align_child(Center, Center)
        .child(text);

    let mark = if place.today { mark.fill(theme.primary) } else { mark };

    let opacity = if place.outside {
        dash::OUTSIDE_DOT_OPACITY
    } else {
        dash::DOT_OPACITY
    };
    let dot_color = faded(theme.on_surface_variant, opacity);

    let mut dots: Vec<Box<dyn Widget>> = (0..count.min(dash::DOTS - usize::from(due)))
        .map(|_| {
            Box::new(
                Rectangle::new()
                    .width(dash::DOT)
                    .height(dash::DOT)
                    .radius(dash::DOT / 2.0)
                    .fill(dot_color),
            ) as Box<dyn Widget>
        })
        .collect();

    if due {
        dots.push(Box::new(
            Rectangle::new()
                .width(dash::DOT)
                .height(dash::DOT)
                .radius(dash::DOT / 2.0)
                .border(dash::RING_BORDER, dot_color),
        ));
    }

    // an empty row still holds the dots' height, so every number sits at the same place
    let dots = Rectangle::new()
        .width(dash::MARK)
        .height(dash::DOT)
        .align_child(Center, Center)
        .child(Row::new(dots).gap(dash::DOT_GAP));

    Column::new(vec![Box::new(mark), Box::new(dots)])
        .gap(dash::MARK_GAP)
        .align(Center)
}

// one place in the grid, its content in the middle
fn cell<W: Widget + 'static>(child: W, width: f32, height: f32) -> Box<dyn Widget> {
    Box::new(
        Rectangle::new()
            .width(width)
            .height(height)
            .align_child(Center, Center)
            .child(child),
    )
}
