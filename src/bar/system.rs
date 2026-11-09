use amane::{Arc, Canvas, Cap, Center, Cpu, Memory, Row, Service, Shape, Widget, children, shapes};

use super::parts::tag;
use crate::stats::Sensors;
use crate::theme::{Theme, bar};

/*
 * SYS, then cpu, memory, gpu and cpu temperature as rings, as neue had them;
 * a sensor this machine doesn't have leaves its ring out instead of showing zero
 */
pub fn view(theme: &Theme) -> Row {
    Row::new(children![tag("SYS", theme), rings(theme)])
        .gap(bar::GROUP_GAP)
        .align(Center)
}

fn rings(theme: &Theme) -> Row {
    let cpu = f32::from(Cpu::read().percent()) / 100.0;
    let memory = f32::from(Memory::read().percent()) / 100.0;

    let sensors = Sensors::read();
    let (gpu, temp) = (sensors.gpu(), sensors.temp());
    drop(sensors);

    let values = [Some(cpu), Some(memory), gpu, temp];

    let rings: Vec<Box<dyn Widget>> = values
        .into_iter()
        .flatten()
        .map(|value| Box::new(ring(value, theme)) as Box<dyn Widget>)
        .collect();

    Row::new(rings).gap(bar::ITEM_GAP).align(Center)
}

// a track with the value over it, from the top, clockwise
fn ring(value: f32, theme: &Theme) -> Canvas {
    let middle = bar::RING / 2.0;

    // the stroke is centered on the radius, so half of it sits outside
    let radius = middle - bar::RING_STROKE / 2.0;

    Canvas::new().width(bar::RING).height(bar::RING).shapes(shapes![
        Arc::new()
            .center(middle, middle)
            .radius(radius)
            .stroke(bar::RING_STROKE, theme.outline_variant),
        Arc::new()
            .center(middle, middle)
            .radius(radius)
            .sweep(360.0 * value.clamp(0.0, 1.0))
            .stroke(bar::RING_STROKE, theme.primary)
            .cap(Cap::Round),
    ])
}
