use amane::{Battery, Center, Column, Cpu, Memory, Parent, Rectangle, Row, Service, Start, Widget};

use super::{Dashboard, block, label, small};
use crate::theme::{Theme, dash, size};

const KIB_PER_GIB: f32 = 1024.0 * 1024.0;

/*
 * the machine in a few small lines: battery, cpu, memory and disk, each a
 * name and a reading. a reading that isn't there, like a desktop's
 * battery or a disk df couldn't read, leaves its line out
 */
pub fn view(theme: &Theme) -> Column {
    let battery = Battery::read();
    let battery = battery.present().then(|| {
        let state = if battery.charging() {
            " · charging"
        } else if battery.full() {
            " · full"
        } else {
            ""
        };

        format!("{}%{state}", battery.percent())
    });

    let cpu = format!("{}%", Cpu::read().percent());

    let memory = Memory::read();
    let memory = gibibytes(memory.used_kib(), memory.total_kib());

    let disk = Dashboard::read().disk.map(|percent| format!("{percent}%"));

    let readings = [
        ("battery", battery),
        ("cpu", Some(cpu)),
        ("memory", Some(memory)),
        ("disk", disk),
    ];

    let lines = readings
        .into_iter()
        .filter_map(|(name, value)| value.map(|value| (name, value)))
        .map(|(name, value)| Box::new(reading(name, value, theme)) as Box<dyn Widget>)
        .collect();

    block(Box::new(label("system", theme)), lines)
}

fn reading(name: &str, value: String, theme: &Theme) -> Row {
    let height = size::SM * 1.5;

    let name = Rectangle::new()
        .width(dash::KEY)
        .height(height)
        .align_child(Start, Center)
        .child(small(name, theme.on_surface_variant));

    Row::new(vec![
        Box::new(name) as Box<dyn Widget>,
        Box::new(small(value, theme.on_surface_variant)),
    ])
    .width(Parent)
    .align(Center)
}

// used of total, like "6.1 of 15.5 GiB"
fn gibibytes(used_kib: u64, total_kib: u64) -> String {
    let (used, total) = (
        used_kib as f32 / KIB_PER_GIB,
        total_kib as f32 / KIB_PER_GIB,
    );

    format!("{used:.1} of {total:.1} GiB")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn memory_reads_in_gibibytes() {
        assert_eq!(gibibytes(6_396_314, 16_252_928), "6.1 of 15.5 GiB");
        assert_eq!(gibibytes(0, 0), "0.0 of 0.0 GiB");
    }
}
