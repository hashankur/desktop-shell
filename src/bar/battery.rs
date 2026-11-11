use amane::{Battery, Center, End, Rectangle, Row, Service, Widget, children};

use super::parts::{hoverable, reading, reveal, ring};
use crate::charge::{self, Charge};
use crate::hover;
use crate::theme::{Theme, bar};

/*
 * the charge as a ring like the stats, the percent, then "bat" after it like
 * a unit, or "charging" while it charges. under the pointer it adds how long
 * is left, "2h 47m left" or "40m to full", as neue's tooltip did. nothing on
 * a machine without one
 */
pub fn view(theme: &Theme, monitor: &str) -> Option<Rectangle> {
    let battery = Battery::read();
    let (present, percent, charging) = (battery.present(), battery.percent(), battery.charging());
    drop(battery);

    if !present {
        return None;
    }

    let key = hover::key(monitor, "battery");
    let amount = hover::amount(&key);
    let label = if charging { "charging" } else { "bat" };

    let mut readings: Vec<Box<dyn Widget>> = vec![Box::new(reading(format!("{percent}%"), label, theme))];

    // read only while it shows, so its estimate doesn't redraw the bar the rest of the time
    let remaining = (amount > 0.0).then(|| Charge::read().remaining()).flatten();

    if let Some(remaining) = remaining {
        let label = if remaining.charging { "to full" } else { "left" };
        let time = reading(charge::duration(remaining.minutes), label, theme);

        if let Some(time) = reveal(time, bar::READING_GAP, amount) {
            readings.push(Box::new(time));
        }
    }

    let row = Row::new(children![
        ring(f32::from(percent.min(100)) / 100.0, theme),
        Row::new(readings).align(End),
    ])
    .gap(bar::ITEM_GAP)
    .align(Center);

    Some(hoverable(row, key))
}
