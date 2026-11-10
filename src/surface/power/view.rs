use amane::{
    Center, Column, Monitor, Parent, Pointer, Rectangle, Row, Service, Text, Weight, Widget,
};

use super::actions::{self, Action};
use super::{Power, choose};
use crate::clock::Clock;
use crate::hover;
use crate::theme::{MONO, SANS, Theme, grid, size, space};

/*
 * the center of the screen: the chosen action as the one large word, and
 * under it either the options in a row and how long the machine has been up,
 * or, once an action is picked, what enter and escape will do
 */
pub fn view(theme: &Theme, monitor: &Monitor) -> Rectangle {
    let power = Power::read();
    let (selected, pending) = (power.selected, power.pending);
    drop(power);

    let action = actions::ALL[selected];

    let word = if pending {
        format!("{}?", action.label())
    } else {
        action.label().to_string()
    };

    let word_color = if pending { theme.primary } else { theme.on_surface };

    let large = Text::new(word)
        .font(SANS)
        .weight(Weight::Light)
        .size(size::LG)
        .color(word_color);

    let below: Box<dyn Widget> = if pending {
        Box::new(
            Text::new(format!("↵ to {} · esc to cancel", action.label()))
                .font(MONO)
                .size(size::SM)
                .color(theme.on_surface_variant),
        )
    } else {
        Box::new(options(selected, theme, &monitor.name))
    };

    let mut items: Vec<Box<dyn Widget>> = vec![Box::new(large), Box::new(spacer(space::LG)), below];

    if !pending {
        items.push(Box::new(spacer(space::MD)));
        items.push(Box::new(
            Text::new(uptime())
                .font(MONO)
                .size(size::SM)
                .color(theme.outline),
        ));
    }

    let width = grid::span(6, monitor.width as f32);

    // a click on the block does nothing; only the empty space around it closes the surface
    let block = Rectangle::new()
        .width(width)
        .height(Parent)
        .align_child(Center, Center)
        .on_click(|_| {})
        .child(Column::new(items).align(Center));

    Rectangle::new()
        .width(Parent)
        .height(Parent)
        .align_child(Center, Center)
        .child(block)
}

fn spacer(height: f32) -> Rectangle {
    Rectangle::new().width(Parent).height(height)
}

// the actions in a row, the chosen one primary
fn options(selected: usize, theme: &Theme, monitor: &str) -> Row {
    let items: Vec<Box<dyn Widget>> = actions::ALL
        .iter()
        .enumerate()
        .map(|(index, action)| Box::new(option(*action, index, selected, theme, monitor)) as Box<dyn Widget>)
        .collect();

    Row::new(items).gap(space::LG).align(Center)
}

fn option(action: Action, index: usize, selected: usize, theme: &Theme, monitor: &str) -> Rectangle {
    let key = hover::key(monitor, &format!("power/{index}"));

    let color = if index == selected || hover::is(&key) {
        theme.primary
    } else {
        theme.on_surface
    };

    let text = Text::new(action.label()).font(SANS).size(size::MD).color(color);

    // fixed to the text's width, since a rectangle can't fit its child
    let width = Widget::width(&text);

    Rectangle::new()
        .width(width)
        .height(size::MD * 1.5)
        .align_child(Center, Center)
        .cursor(Pointer)
        .on_hover(move |inside| hover::set(&key, inside))
        .on_click(move |_| choose(index))
        .child(text)
}

// "up 3h 12m"; the clock is read only so this redraws when the minute changes
fn uptime() -> String {
    drop(Clock::read());

    let seconds = std::fs::read_to_string("/proc/uptime")
        .ok()
        .and_then(|text| text.split_whitespace().next().and_then(|field| field.parse::<f64>().ok()))
        .unwrap_or(0.0);

    uptime_label(seconds)
}

fn uptime_label(seconds: f64) -> String {
    let minutes = (seconds / 60.0) as u64;

    let (days, hours, minutes) = (minutes / 1440, minutes % 1440 / 60, minutes % 60);

    match (days, hours) {
        (0, 0) => format!("up {minutes}m"),
        (0, _) => format!("up {hours}h {minutes}m"),
        _ => format!("up {days}d {hours}h"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_like_the_prototype() {
        assert_eq!(uptime_label(3.0 * 3600.0 + 12.0 * 60.0 + 40.0), "up 3h 12m");
    }

    #[test]
    fn short_and_long_uptimes() {
        assert_eq!(uptime_label(42.0 * 60.0), "up 42m");
        assert_eq!(uptime_label(0.0), "up 0m");
        assert_eq!(uptime_label(2.0 * 86400.0 + 5.0 * 3600.0 + 59.0 * 60.0), "up 2d 5h");
    }
}
