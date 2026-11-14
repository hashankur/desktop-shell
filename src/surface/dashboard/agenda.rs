use amane::{Center, Color, Column, Parent, Rectangle, Row, Service, Start, Text, Widget, children};

use super::parts::{label, line, small};
use super::task;
use crate::calendar::days::{heading, hours, upcoming};
use crate::calendar::{Calendar, Event, agenda};
use crate::clock::Clock;
use crate::tasks::{Task, Tasks};
use crate::theme::{SANS, Theme, dash, space};

/*
 * the days under the month: today, then the next days that have something
 * on, each event with its hours, its title and how long it runs, and each
 * task due with its tick. the next event is the accent and says how soon;
 * what's over has gone quiet. tasks gone by stay at the top of today until
 * they're done. it stops at a few days and lines, saying how many more a
 * day has, so a busy week can't run off the screen. none until the
 * calendar is signed in
 */
pub fn view(theme: &Theme, monitor: &str, width: f32) -> Option<Column> {
    let clock = Clock::read();
    let (now, offset, today) = (clock.now(), clock.offset(), clock.days());
    drop(clock);

    let calendar = Calendar::read();

    if !calendar.signed_in() {
        return None;
    }

    let tasks = Tasks::read();
    let due: &[Task] = if tasks.ready() { tasks.tasks() } else { &[] };

    // what a day lists among the tasks: its own, and on today the ones gone by too
    let due_on = |day: i64| -> Vec<&Task> {
        due.iter()
            .filter(|task| task.due.is_some_and(|due| due == day || (day == today && due < today)))
            .collect()
    };

    let events = calendar.events();
    let next = agenda::next(events, now, offset);

    let mut left = dash::AGENDA_LINES;
    let mut groups: Vec<Box<dyn Widget>> = Vec::new();

    for (day, on) in upcoming(events, today, agenda::AHEAD, offset, |day| !due_on(day).is_empty())
        .into_iter()
        .take(dash::AGENDA_DAYS)
    {
        if left == 0 {
            break;
        }

        let mut lines: Vec<Box<dyn Widget>> = vec![Box::new(label(&heading(day, today), theme))];

        let day_tasks = due_on(day);
        let (late, on_time): (Vec<&Task>, Vec<&Task>) =
            day_tasks.into_iter().partition(|task| task.due.is_some_and(|due| due < day));

        let total = late.len() + on.len() + on_time.len();

        if total == 0 {
            lines.push(Box::new(small("nothing on", theme.on_surface_variant)));
            left -= 1;
        }

        let shown = total.min(left);
        let main_list = tasks.default_list().map(|list| list.id.as_str());

        let task_line = |task: &Task| -> Box<dyn Widget> {
            let list = if Some(task.list.as_str()) == main_list {
                ""
            } else {
                tasks.list_title(&task.list)
            };

            Box::new(task::entry(task, list, today, theme, monitor))
        };

        let mut rows: Vec<Box<dyn Widget>> = late.iter().map(|task| task_line(task)).collect();

        for event in &on {
            let state = if next == Some(*event) {
                State::Next
            } else if event.end <= now {
                State::Over
            } else {
                State::Coming
            };

            let trailing = match state {
                State::Next => agenda::countdown(event, now, offset),
                State::Coming if !event.all_day => length(event),
                _ => String::new(),
            };

            rows.push(Box::new(entry(&hours(event, day, offset), &event.title, &trailing, state, theme)));
        }

        rows.extend(on_time.iter().map(|task| task_line(task)));

        lines.extend(rows.into_iter().take(shown));

        if total > shown {
            lines.push(Box::new(small(format!("+{} more", total - shown), theme.outline)));
        }

        left -= shown;

        groups.push(Box::new(Column::new(lines).width(width).gap(space::XS)));
    }

    drop(tasks);
    drop(calendar);

    Some(Column::new(groups).width(width).gap(space::MD))
}

#[derive(Clone, Copy, PartialEq)]
enum State {
    Over,
    Next,
    Coming,
}

// how long it runs, like "45m" or "2h"
fn length(event: &Event) -> String {
    agenda::duration((event.end - event.start).max(0) / 60)
}

// a line of the agenda: the hours in their own column, the title, and something small at the end
fn entry(time: &str, title: &str, trailing: &str, state: State, theme: &Theme) -> Row {
    let (quiet, loud): (Color, Color) = match state {
        State::Next => (theme.primary, theme.primary),
        State::Over => (theme.outline, theme.outline),
        State::Coming => (theme.on_surface_variant, theme.on_surface),
    };

    let time = Rectangle::new()
        .width(dash::TIME)
        .height(line(dash::AGENDA))
        .align_child(Start, Center)
        .child(small(time, quiet));

    let title = Text::new(title)
        .font(SANS)
        .size(dash::AGENDA)
        .color(loud)
        .elide();

    Row::new(children![time, title, small(trailing, quiet)])
        .width(Parent)
        .gap(space::MD)
        .align(Center)
}
