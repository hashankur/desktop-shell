use crate::clock::{civil_date, days_from_civil};

pub const DAY: i64 = 24 * 60 * 60;

/*
 * google gives a timed event's start like "2026-11-11T09:30:00+05:30" (or
 * with a Z, or fractional seconds) and an all-day one's as a bare
 * "2026-11-11". both come back as seconds since 1970 in utc; a bare date is
 * that day's local midnight, which needs the offset
 */
pub fn parse(text: &str, offset: i64) -> Option<(i64, bool)> {
    let days = date(text.get(0..10)?)?;

    if text.len() == 10 {
        return Some((days * DAY - offset, true));
    }

    if !matches!(text.get(10..11)?, "T" | "t" | " ") {
        return None;
    }

    let hours = number(text.get(11..13)?)?;
    let minutes = number(text.get(14..16)?)?;
    let seconds = number(text.get(17..19)?)?;

    if text.get(13..14)? != ":" || text.get(16..17)? != ":" || hours > 23 || minutes > 59 || seconds > 60 {
        return None;
    }

    // fractional seconds are dropped; nothing on screen is finer than a minute
    let rest = text.get(19..)?;
    let zone = rest.trim_start_matches(|c: char| c == '.' || c.is_ascii_digit());

    let zone_offset = match zone {
        "Z" | "z" => 0,
        _ => {
            let sign = match zone.get(0..1)? {
                "+" => 1,
                "-" => -1,
                _ => return None,
            };

            if zone.len() != 6 || zone.get(3..4)? != ":" {
                return None;
            }

            sign * (number(zone.get(1..3)?)? * 3600 + number(zone.get(4..6)?)? * 60)
        }
    };

    Some((days * DAY + hours * 3600 + minutes * 60 + seconds - zone_offset, false))
}

// "2026-11-11" as days since 1970
fn date(text: &str) -> Option<i64> {
    if text.get(4..5)? != "-" || text.get(7..8)? != "-" {
        return None;
    }

    let year = number(text.get(0..4)?)?;
    let month = number(text.get(5..7)?)?;
    let day = number(text.get(8..10)?)?;

    if !(1..=12).contains(&month) || !(1..=31).contains(&day) {
        return None;
    }

    Some(days_from_civil(year, month, day))
}

fn number(text: &str) -> Option<i64> {
    if !text.chars().all(|c| c.is_ascii_digit()) {
        return None;
    }

    text.parse().ok()
}

// seconds since 1970 in utc, the way google is asked for a window: "2026-11-11T00:00:00Z"
pub fn rfc3339(utc: i64) -> String {
    let (year, month, day) = civil_date(utc.div_euclid(DAY));
    let seconds = utc.rem_euclid(DAY);

    format!(
        "{year:04}-{month:02}-{day:02}T{:02}:{:02}:{:02}Z",
        seconds / 3600,
        seconds % 3600 / 60,
        seconds % 60
    )
}

// the utc instant of the local midnight that starts the day `utc` falls on
pub fn midnight(utc: i64, offset: i64) -> i64 {
    (utc + offset).div_euclid(DAY) * DAY - offset
}

#[cfg(test)]
mod tests {
    use super::*;

    // 2026-11-11 00:00 utc
    const ELEVENTH: i64 = 1_794_355_200;

    #[test]
    fn counts_days_both_ways() {
        assert_eq!(days_from_civil(1970, 1, 1), 0);
        assert_eq!(days_from_civil(2026, 11, 11) * DAY, ELEVENTH);
        assert_eq!(days_from_civil(2024, 2, 29), 19_782);

        for days in [-1, 0, 59, 19_782, 20_403, 40_000] {
            let (year, month, day) = civil_date(days);

            assert_eq!(days_from_civil(year, month, day), days);
        }
    }

    #[test]
    fn reads_timed_starts_in_any_zone() {
        let nine_utc = ELEVENTH + 9 * 3600;

        assert_eq!(parse("2026-11-11T09:00:00Z", 0), Some((nine_utc, false)));
        assert_eq!(parse("2026-11-11T09:00:00.000Z", 0), Some((nine_utc, false)));
        assert_eq!(parse("2026-11-11T14:30:00+05:30", 0), Some((nine_utc, false)));
        assert_eq!(parse("2026-11-11T04:00:00-05:00", 0), Some((nine_utc, false)));
    }

    #[test]
    fn reads_a_bare_date_as_local_midnight() {
        // at +05:30, local midnight is 18:30 utc the day before
        assert_eq!(
            parse("2026-11-11", 19_800),
            Some((ELEVENTH - 19_800, true))
        );
    }

    #[test]
    fn refuses_what_it_cannot_read() {
        for text in ["", "2026-11", "2026/11/11", "2026-13-01", "2026-11-11T25:00:00Z", "2026-11-11T09:00:00", "2026-11-11T09:00:00+0530", "tomorrow!!"] {
            assert_eq!(parse(text, 0), None, "{text}");
        }
    }

    #[test]
    fn writes_the_window_for_google() {
        assert_eq!(rfc3339(ELEVENTH + 9 * 3600 + 5 * 60 + 7), "2026-11-11T09:05:07Z");
    }

    #[test]
    fn finds_the_local_midnight() {
        let offset = 19_800;
        let local_midnight = ELEVENTH - offset;

        assert_eq!(midnight(local_midnight, offset), local_midnight);
        assert_eq!(midnight(local_midnight + DAY - 1, offset), local_midnight);
        assert_eq!(midnight(local_midnight - 1, offset), local_midnight - DAY);
    }
}
