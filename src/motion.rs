use std::collections::HashMap;
use std::sync::{Mutex, PoisonError};
use std::time::Instant;

use crate::theme::timing;

// leaving is quicker than arriving, as the design asks
const _: () = assert!(timing::OUT < timing::IN);

/*
 * how a surface or the poster comes and goes: a fade plus a small slide, no
 * springs, no overshoot. coming in, the scrim fades first and the content
 * follows a beat later, decelerating; going out the content leaves first and
 * the scrim follows, faster, accelerating. nothing moves at rest
 */

// decelerate: fast at the start, settling gently, for things arriving
fn decelerate(progress: f32) -> f32 {
    let remaining = 1.0 - progress;

    1.0 - remaining * remaining * remaining
}

// accelerate: slow at the start, quick at the end, for things leaving
fn accelerate(progress: f32) -> f32 {
    progress * progress * progress
}

fn lerp(from: f32, to: f32, amount: f32) -> f32 {
    from + (to - from) * amount
}

// how long after `delay` a move of `duration` has got, from 0 to 1
fn progress(elapsed: f32, delay: f32, duration: f32) -> f32 {
    ((elapsed - delay) / duration).clamp(0.0, 1.0)
}

/*
 * where the scrim and the content are, from 0 (gone) to 1 (fully there).
 * reversing halfway starts from where each is, so nothing jumps
 */
#[derive(Clone, Copy)]
pub struct Timeline {
    open: bool,
    since: Instant,
    from_scrim: f32,
    from_content: f32,
}

impl Timeline {
    // already where `open` puts it, with nothing moving
    pub fn resting(open: bool, now: Instant) -> Self {
        let value = if open { 1.0 } else { 0.0 };

        Self {
            open,
            since: now,
            from_scrim: value,
            from_content: value,
        }
    }

    fn elapsed(&self, now: Instant) -> f32 {
        now.saturating_duration_since(self.since).as_secs_f32()
    }

    // (scrim, content)
    pub fn at(&self, now: Instant) -> (f32, f32) {
        let elapsed = self.elapsed(now);

        if self.open {
            let scrim = decelerate(progress(elapsed, 0.0, timing::IN));
            let content = decelerate(progress(elapsed, timing::BEAT, timing::IN));

            (
                lerp(self.from_scrim, 1.0, scrim),
                lerp(self.from_content, 1.0, content),
            )
        } else {
            let content = accelerate(progress(elapsed, 0.0, timing::OUT));
            let scrim = accelerate(progress(elapsed, timing::BEAT, timing::OUT));

            (
                lerp(self.from_scrim, 0.0, scrim),
                lerp(self.from_content, 0.0, content),
            )
        }
    }

    // true while either is still on its way; a timeline already where it is heading never is
    pub fn moving(&self, now: Instant) -> bool {
        let (scrim, content) = if self.open { (1.0, 1.0) } else { (0.0, 0.0) };

        if self.from_scrim == scrim && self.from_content == content {
            return false;
        }

        let total = timing::BEAT + if self.open { timing::IN } else { timing::OUT };

        self.elapsed(now) < total
    }

    pub fn set(&mut self, open: bool, now: Instant) {
        if open == self.open {
            return;
        }

        let (scrim, content) = self.at(now);

        self.open = open;
        self.since = now;
        self.from_scrim = scrim;
        self.from_content = content;
    }
}

// what a view needs to draw one frame of it
pub struct Presence {
    pub scrim: f32,
    pub content: f32,

    // how far below its place the content still is, in pixels
    pub shift: f32,

    // true until it has arrived or left; the window has to stay shown until then
    pub moving: bool,
}

// timelines belong to the views, which run on one thread, so a plain lock is enough
static TIMELINES: Mutex<Option<HashMap<String, Timeline>>> = Mutex::new(None);

/*
 * one frame of the thing called `key`, open or not. called from a view: it
 * notes the change, and while moving asks for the next frame so the window
 * keeps drawing, and stops asking once it has settled so it can rest
 */
pub fn presence(key: &str, open: bool) -> Presence {
    let now = Instant::now();

    let mut timelines = TIMELINES.lock().unwrap_or_else(PoisonError::into_inner);

    let timeline = timelines
        .get_or_insert_with(HashMap::new)
        .entry(key.to_string())
        // a timeline first seen starts where it is asked to be: nothing animates in at startup
        .or_insert_with(|| Timeline::resting(open, now));

    timeline.set(open, now);

    let (scrim, content) = timeline.at(now);
    let moving = timeline.moving(now);

    drop(timelines);

    if moving {
        amane::request_frame();
    }

    Presence {
        scrim,
        content,
        shift: timing::SHIFT * (1.0 - content),
        moving,
    }
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use super::*;

    fn after(start: Instant, seconds: f32) -> Instant {
        start + Duration::from_secs_f32(seconds)
    }

    #[test]
    fn rests_closed_until_opened() {
        let start = Instant::now();
        let timeline = Timeline::resting(false, start);

        assert_eq!(timeline.at(after(start, 5.0)), (0.0, 0.0));
        assert!(!timeline.moving(start));
    }

    #[test]
    fn the_scrim_leads_and_the_content_follows_a_beat_later() {
        let start = Instant::now();
        let mut timeline = Timeline::resting(false, start);

        timeline.set(true, start);

        // just inside the beat: the scrim has started, the content hasn't
        let (scrim, content) = timeline.at(after(start, timing::BEAT * 0.9));

        assert!(scrim > 0.0);
        assert_eq!(content, 0.0);

        // later the content is moving too, still behind the scrim
        let (scrim, content) = timeline.at(after(start, timing::BEAT + timing::IN * 0.3));

        assert!(content > 0.0 && content < scrim);
    }

    #[test]
    fn arrives_fully_and_stops_moving() {
        let start = Instant::now();
        let mut timeline = Timeline::resting(false, start);

        timeline.set(true, start);

        let end = after(start, timing::BEAT + timing::IN + 0.01);

        assert_eq!(timeline.at(end), (1.0, 1.0));
        assert!(timeline.moving(after(start, timing::IN)));
        assert!(!timeline.moving(end));
    }

    #[test]
    fn leaving_takes_the_content_first_and_is_faster() {
        let start = Instant::now();
        let mut timeline = Timeline::resting(false, start);

        timeline.set(true, start);
        timeline.set(false, after(start, 1.0));

        let (scrim, content) = timeline.at(after(start, 1.0 + timing::OUT * 0.5));

        // the content is already leaving while the scrim waits out the beat
        assert!(content < 1.0);
        assert!(scrim >= content);

        let gone = after(start, 1.0 + timing::BEAT + timing::OUT + 0.01);

        assert_eq!(timeline.at(gone), (0.0, 0.0));
        assert!(!timeline.moving(gone));

    }

    #[test]
    fn reversing_halfway_never_jumps() {
        let start = Instant::now();
        let mut timeline = Timeline::resting(false, start);

        timeline.set(true, start);

        let midway = after(start, timing::BEAT + timing::IN * 0.4);
        let before = timeline.at(midway);

        timeline.set(false, midway);

        let reversed = timeline.at(midway);

        assert!((before.0 - reversed.0).abs() < 1e-4);
        assert!((before.1 - reversed.1).abs() < 1e-4);
    }

    #[test]
    fn setting_the_same_state_again_changes_nothing() {
        let start = Instant::now();
        let mut timeline = Timeline::resting(false, start);

        timeline.set(true, start);

        let at = after(start, 0.1);
        let once = timeline.at(at);

        timeline.set(true, after(start, 0.05));

        assert_eq!(timeline.at(at), once);
    }

    #[test]
    fn a_timeline_resting_open_is_fully_there_and_still() {
        let start = Instant::now();
        let timeline = Timeline::resting(true, start);

        assert_eq!(timeline.at(start), (1.0, 1.0));
        assert!(!timeline.moving(start));
    }
}
