use amane::Service;

use super::Surface;
use crate::motion::{self, Presence};

/*
 * how far an open surface has come over one output: whether it is on this
 * output, whether its window is shown (open, or still fading out), and the
 * fade. the bar asks too, so it steps back for exactly as long as the
 * surface's window covers it
 */
pub struct Cover {
    pub here: bool,
    pub drawn: bool,
    pub motion: Presence,
}

pub fn cover(monitor: &str) -> Cover {
    let surface = Surface::read();
    let (here, on_output) = (surface.shows(monitor), surface.on_output(monitor));
    drop(surface);

    let motion = motion::presence(&format!("surface/{monitor}"), here);

    Cover {
        here,
        drawn: on_output && (here || motion.moving),
        motion,
    }
}

/*
 * the surface's window covers the bar, so over the bar's strip three tints
 * stack: the bar's own, the surface's scrim, and a little extra from the
 * strip's copy of the bar. together they come to the same `total` darkness
 * the bar always has, so the strip neither flashes lighter in the middle of
 * the fade nor ends up darker than the bar was. `scrim` is the surface's
 * fade, 0 closed to 1 open
 */
pub fn bar_tint(total: f32, scrim: f32) -> f32 {
    total * (1.0 - scrim.clamp(0.0, 1.0))
}

pub fn surface_tint(total: f32, scrim: f32) -> f32 {
    total * scrim.clamp(0.0, 1.0)
}

// what the strip's copy adds over the other two
pub fn strip_tint(total: f32, scrim: f32) -> f32 {
    let (bar, surface) = (bar_tint(total, scrim), surface_tint(total, scrim));

    // a total of 1 can't be made up, and neither can a total of 0 be lowered
    1.0 - (1.0 - total) / ((1.0 - bar) * (1.0 - surface)).max(f32::EPSILON)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn together(total: f32, scrim: f32) -> f32 {
        let layers = [bar_tint(total, scrim), surface_tint(total, scrim), strip_tint(total, scrim)];

        1.0 - layers.iter().map(|alpha| 1.0 - alpha).product::<f32>()
    }

    #[test]
    fn the_strip_keeps_the_darkness_of_the_bar_all_through_the_fade() {
        for step in 0..=20 {
            let scrim = step as f32 / 20.0;

            assert!((together(0.6, scrim) - 0.6).abs() < 1e-4, "at {scrim}");
        }
    }

    #[test]
    fn at_rest_the_strip_adds_nothing() {
        assert!(strip_tint(0.6, 0.0).abs() < 1e-5);
        assert!(strip_tint(0.6, 1.0).abs() < 1e-5);
        assert_eq!(bar_tint(0.6, 0.0), 0.6);
        assert_eq!(bar_tint(0.6, 1.0), 0.0);
    }
}
