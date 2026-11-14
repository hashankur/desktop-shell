use crate::clock::{civil_date, days_from_civil};

/*
 * due dates as local days since 1970, like Clock::days. google keeps only
 * a task's date: it sends it as midnight utc of that date and drops any
 * time it's given. so the date is read and written as it is, never moved
 * through the local offset, which would put it a day off west or east of utc
 */

// 1970-01-01 was a thursday
const WEEKDAYS: [&str; 7] = ["thu", "fri", "sat", "sun", "mon", "tue", "wed"];

const MONTHS: [&str; 12] = [
    "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec",
];

// "2026-11-14T00:00:00.000Z" as its date; none for no date or one that isn't read
pub fn parse(text: &str) -> Option<i64> {
    let date = text.get(0..10)?;

    if date.get(4..5)? != "-" || date.get(7..8)? != "-" {
        return None;
    }

    let number = |range: std::ops::Range<usize>| -> Option<i64> {
        let part = date.get(range)?;

        part.bytes().all(|byte| byte.is_ascii_digit()).then(|| part.parse().ok())?
    };

    let (year, month, day) = (number(0..4)?, number(5..7)?, number(8..10)?);

    if !(1..=12).contains(&month) || !(1..=31).contains(&day) {
        return None;
    }

    Some(days_from_civil(year, month, day))
}

// a day the way google takes a due date
pub fn format(day: i64) -> String {
    let (year, month, date) = civil_date(day);

    format!("{year:04}-{month:02}-{date:02}T00:00:00.000Z")
}

/*
 * when a task is due, said shortly: "today", "tomorrow", a weekday within
 * the week, then "27 nov"; one that's gone by says how long ago, "3d late"
 */
pub fn label(day: i64, today: i64) -> String {
    let away = day - today;

    if away < 0 {
        return format!("{}d late", -away);
    }

    match away {
        0 => String::from("today"),
        1 => String::from("tomorrow"),
        2..=6 => format!("{} {}", weekday(day), civil_date(day).2),
        _ => {
            let (_, month, date) = civil_date(day);

            format!("{date} {}", MONTHS.get((month - 1) as usize).copied().unwrap_or_default())
        }
    }
}

fn weekday(day: i64) -> &'static str {
    WEEKDAYS.get(day.rem_euclid(7) as usize).copied().unwrap_or_default()
}

/*
 * a quick-added task's words, with a date at the end taken off as its due
 * date: "today", "tomorrow", a weekday, or a day and month either way
 * round ("20 nov", "nov 20"). a weekday is the next one after today, since
 * today has its own word; a day and month that's gone by this year is next
 * year's. the date is only taken when words are left for the title, so a
 * task called "friday" stays one
 */
pub fn split(text: &str, today: i64) -> (String, Option<i64>) {
    let words: Vec<&str> = text.split_whitespace().collect();

    for taken in [2, 1] {
        if words.len() <= taken {
            continue;
        }

        let (title, end) = words.split_at(words.len() - taken);

        if let Some(day) = date_words(end, today) {
            return (title.join(" "), Some(day));
        }
    }

    (words.join(" "), None)
}

fn date_words(words: &[&str], today: i64) -> Option<i64> {
    let lower: Vec<String> = words.iter().map(|word| word.to_lowercase()).collect();

    match lower.as_slice() {
        [word] => match word.as_str() {
            "today" | "tod" => Some(today),
            "tomorrow" | "tmrw" | "tmr" => Some(today + 1),
            other => {
                let wanted = name_index(other, &WEEKDAYS)? as i64;
                let now = today.rem_euclid(7);

                // the next one after today: one to seven days on
                let ahead = (wanted - now - 1).rem_euclid(7) + 1;

                Some(today + ahead)
            }
        },

        [first, second] => {
            let (date, month) = match (first.parse::<i64>(), second.parse::<i64>()) {
                (Ok(date), Err(_)) => (date, name_index(second, &MONTHS)? as i64 + 1),
                (Err(_), Ok(date)) => (date, name_index(first, &MONTHS)? as i64 + 1),
                _ => return None,
            };

            if !(1..=31).contains(&date) {
                return None;
            }

            let (year, _, _) = civil_date(today);
            let this_year = days_from_civil(year, month, date);

            // a date that doesn't exist, like 31 nov, rolls into the next month; refuse it
            if civil_date(this_year) != (year, month, date) {
                return None;
            }

            if this_year >= today {
                Some(this_year)
            } else {
                Some(days_from_civil(year + 1, month, date))
            }
        }

        _ => None,
    }
}

/*
 * which of three-letter names a word is: the name itself, or a longer
 * word starting with it ("friday", "november"), but no shorter
 */
fn name_index(word: &str, names: &[&str]) -> Option<usize> {
    if word.len() < 3 {
        return None;
    }

    let start = word.get(0..3)?;

    names.iter().position(|name| *name == start).filter(|_| {
        // "sat" or "saturday", not "satchel"
        word.len() == 3 || full_names().iter().any(|full| full.starts_with(word))
    })
}

fn full_names() -> [&'static str; 19] {
    [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "january",
        "february", "march", "april", "june", "july", "august", "september", "sept", "october",
        "november", "december",
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    // friday 2026-11-13
    fn today() -> i64 {
        days_from_civil(2026, 11, 13)
    }

    fn day(year: i64, month: i64, date: i64) -> Option<i64> {
        Some(days_from_civil(year, month, date))
    }

    #[test]
    fn reads_and_writes_the_date_as_it_is() {
        assert_eq!(parse("2026-11-14T00:00:00.000Z"), day(2026, 11, 14));
        assert_eq!(format(days_from_civil(2026, 11, 14)), "2026-11-14T00:00:00.000Z");
        assert_eq!(parse(""), None);
        assert_eq!(parse("2026-13-01T00:00:00.000Z"), None);
        assert_eq!(parse("soon"), None);

        for date in [today(), today() + 400, 0] {
            assert_eq!(parse(&format(date)), Some(date));
        }
    }

    #[test]
    fn labels_how_soon() {
        let today = today();

        assert_eq!(label(today, today), "today");
        assert_eq!(label(today + 1, today), "tomorrow");
        assert_eq!(label(today + 3, today), "mon 16");
        assert_eq!(label(today + 14, today), "27 nov");
        assert_eq!(label(today - 3, today), "3d late");
    }

    #[test]
    fn takes_a_date_off_the_end() {
        let today = today();

        assert_eq!(split("oat milk sat", today), (String::from("oat milk"), day(2026, 11, 14)));
        assert_eq!(split("call mum today", today), (String::from("call mum"), Some(today)));
        assert_eq!(split("call mum Tomorrow", today), (String::from("call mum"), Some(today + 1)));
        assert_eq!(split("invoice 20 nov", today), (String::from("invoice"), day(2026, 11, 20)));
        assert_eq!(split("invoice nov 20", today), (String::from("invoice"), day(2026, 11, 20)));
        assert_eq!(split("tyres 4 january", today), (String::from("tyres"), day(2027, 1, 4)));
    }

    #[test]
    fn a_weekday_is_the_next_one_after_today() {
        let today = today();

        assert_eq!(split("standup fri", today).1, Some(today + 7));
        assert_eq!(split("standup friday", today).1, Some(today + 7));
        assert_eq!(split("standup thu", today).1, Some(today + 6));
        assert_eq!(split("standup mon", today).1, day(2026, 11, 16));
    }

    #[test]
    fn leaves_words_that_are_not_dates() {
        let today = today();

        assert_eq!(split("friday", today), (String::from("friday"), None));
        assert_eq!(split("buy a satchel", today), (String::from("buy a satchel"), None));
        assert_eq!(split("read chapter 20", today), (String::from("read chapter 20"), None));
        assert_eq!(split("plan 31 nov", today), (String::from("plan 31 nov"), None));
        assert_eq!(split("  spaced   out  ", today), (String::from("spaced out"), None));
    }
}
