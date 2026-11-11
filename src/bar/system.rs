use amane::{Center, Cpu, End, Memory, Rectangle, Row, Service, Widget, children};

use super::parts::{hoverable, reading, reveal, ring, unit};
use crate::hover;
use crate::stats::Sensors;
use crate::theme::{Theme, bar};

/*
 * cpu, memory, gpu and cpu temperature as rings, as neue had them, then
 * "sys" after them like a unit; a sensor this machine doesn't have leaves
 * its ring out instead of showing zero. under the pointer "sys" gives way
 * to the numbers, "12% cpu  40% mem  5% gpu  52° temp", where neue had
 * a tooltip per ring
 */
pub fn view(theme: &Theme, monitor: &str) -> Rectangle {
    let key = hover::key(monitor, "system");
    let amount = hover::amount(&key);
    let stats = Stats::read();

    // "sys" folds away as the readings unfold, so the item grows in one smooth move
    let detail: Vec<Box<dyn Widget>> = [
        reveal(unit("sys", theme), 0.0, 1.0 - amount),
        reveal(readings(&stats, theme), 0.0, amount),
    ]
    .into_iter()
    .flatten()
    .map(|part| Box::new(part) as Box<dyn Widget>)
    .collect();

    let row = Row::new(children![rings(&stats, theme), Row::new(detail).align(Center)])
        .gap(bar::ITEM_GAP)
        .align(Center);

    hoverable(row, key)
}

// one read of everything the rings and the readings show
struct Stats {
    cpu: f32,
    memory: f32,
    gpu: Option<f32>,
    temp: Option<f32>,
    celsius: Option<f32>,
}

impl Stats {
    fn read() -> Self {
        let cpu = f32::from(Cpu::read().percent()) / 100.0;
        let memory = f32::from(Memory::read().percent()) / 100.0;

        let sensors = Sensors::read();
        let (gpu, temp, celsius) = (sensors.gpu(), sensors.temp(), sensors.celsius());
        drop(sensors);

        Self { cpu, memory, gpu, temp, celsius }
    }
}

fn rings(stats: &Stats, theme: &Theme) -> Row {
    let values = [Some(stats.cpu), Some(stats.memory), stats.gpu, stats.temp];

    let rings: Vec<Box<dyn Widget>> = values
        .into_iter()
        .flatten()
        .map(|value| Box::new(ring(value, theme)) as Box<dyn Widget>)
        .collect();

    Row::new(rings).gap(bar::ITEM_GAP).align(Center)
}

// the rings' numbers in the rings' order, each with its unit
fn readings(stats: &Stats, theme: &Theme) -> Row {
    let percent = |value: f32| format!("{}%", (value * 100.0).round());

    let values = [
        Some((percent(stats.cpu), "cpu")),
        Some((percent(stats.memory), "mem")),
        stats.gpu.map(|gpu| (percent(gpu), "gpu")),
        stats.celsius.map(|celsius| (format!("{}°", celsius.round()), "temp")),
    ];

    let readings: Vec<Box<dyn Widget>> = values
        .into_iter()
        .flatten()
        .map(|(value, label)| Box::new(reading(value, label, theme)) as Box<dyn Widget>)
        .collect();

    Row::new(readings).gap(bar::READING_GAP).align(End)
}
