use std::time::{Duration, SystemTime, UNIX_EPOCH};

use amane::Service;

// the offset is asked for again every 10 minutes, to follow daylight saving changes
const OFFSET_REFRESH: u32 = 600;

const SECONDS_PER_DAY: i64 = 24 * 60 * 60;

// 1970-01-01 was a thursday
const WEEKDAYS: [&str; 7] = ["Thu", "Fri", "Sat", "Sun", "Mon", "Tue", "Wed"];

const MONTHS: [&str; 12] = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];

/*
 * there is no chrono in an amane shell, so the utc offset comes from
 * `date` and the time is counted from the system clock; it ticks every
 * second but only a new minute redraws anything
 */
#[derive(Default)]
pub struct Clock {
    // seconds east of utc
    offset: i64,

    ticks: u32,

    // seconds since 1970, in local time
    local: i64,
}

impl Service for Clock {
    fn new() -> Self {
        let mut clock = Self {
            offset: read_offset(),
            ..Self::default()
        };

        clock.update();

        clock
    }

    fn update(&mut self) -> bool {
        let minute = self.local.div_euclid(60);

        self.ticks += 1;

        if self.ticks >= OFFSET_REFRESH {
            self.ticks = 0;
            self.offset = read_offset();
        }

        let since_epoch = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or(Duration::ZERO)
            .as_secs() as i64;

        self.local = since_epoch + self.offset;

        self.local.div_euclid(60) != minute
    }
}

const WEEKDAY_NAMES: [&str; 7] = [
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
];

const MONTH_NAMES: [&str; 12] = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
];

impl Clock {
    // 24-hour time for the poster, like "15:49"
    pub fn hm(&self) -> String {
        let today = self.local.rem_euclid(SECONDS_PER_DAY);

        format!("{:02}:{:02}", today / 3600, today % 3600 / 60)
    }

    // the poster's date line, like "Sunday 9 November"
    pub fn day(&self) -> String {
        let days = self.local.div_euclid(SECONDS_PER_DAY);

        let weekday = WEEKDAY_NAMES[days.rem_euclid(7) as usize];
        let (_, month, day) = civil_date(days);

        format!("{weekday} {day} {}", MONTH_NAMES[(month - 1) as usize])
    }

    // seconds since 1970 in utc, the way calendar events are kept
    pub fn now(&self) -> i64 {
        self.local - self.offset
    }

    // seconds east of utc
    pub fn offset(&self) -> i64 {
        self.offset
    }

    // days since 1970 in local time, for the dashboard's calendar
    pub fn days(&self) -> i64 {
        self.local.div_euclid(SECONDS_PER_DAY)
    }

    // the dashboard's large line, like "Tuesday 10"
    pub fn weekday_and_day(&self) -> String {
        let days = self.days();

        let (_, _, day) = civil_date(days);

        format!("{} {day}", WEEKDAY_NAMES[days.rem_euclid(7) as usize])
    }

    // the month in full and the year, like "November 2026"
    pub fn month_and_year(&self) -> String {
        let (year, month, _) = civil_date(self.days());

        format!("{} {year}", MONTH_NAMES[(month - 1) as usize])
    }

    // the bar's time, like ("4:03", "PM"); the period is drawn smaller
    pub fn time(&self) -> (String, &'static str) {
        twelve_hour(self.local.rem_euclid(SECONDS_PER_DAY))
    }

    // the bar's date after the time, like "Tue 10 Nov"
    pub fn date(&self) -> String {
        let days = self.days();

        let weekday = WEEKDAYS[days.rem_euclid(7) as usize];
        let (_, month, day) = civil_date(days);

        format!("{weekday} {day:02} {}", MONTHS[(month - 1) as usize])
    }

}

// seconds into the day as a 12-hour time without a leading zero, and its period
fn twelve_hour(today: i64) -> (String, &'static str) {
    let hours = today / 3600;
    let minutes = today % 3600 / 60;

    let period = if hours < 12 { "AM" } else { "PM" };

    // 0 and 12 both read as 12
    let hours = match hours % 12 {
        0 => 12,
        hours => hours,
    };

    (format!("{hours}:{minutes:02}"), period)
}

// `date +%z` prints like +0530; anything unreadable counts as utc
pub fn read_offset() -> i64 {
    let text = amane::output("date +%z");

    let (sign, digits) = match text.split_at_checked(1) {
        Some(("-", digits)) => (-1, digits),
        Some(("+", digits)) => (1, digits),
        _ => return 0,
    };

    let (Some(hours), Some(minutes)) = (
        digits.get(0..2).and_then(|h| h.parse::<i64>().ok()),
        digits.get(2..4).and_then(|m| m.parse::<i64>().ok()),
    ) else {
        return 0;
    };

    sign * (hours * 3600 + minutes * 60)
}

// days since 1970 to year, month from 1, day from 1 (howard hinnant's algorithm)
pub fn civil_date(days: i64) -> (i64, i64, i64) {
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let day_of_era = z.rem_euclid(146_097);
    let year_of_era = (day_of_era - day_of_era / 1460 + day_of_era / 36_524 - day_of_era / 146_096) / 365;
    let day_of_year = day_of_era - (365 * year_of_era + year_of_era / 4 - year_of_era / 100);
    let month_index = (5 * day_of_year + 2) / 153;
    let day = day_of_year - (153 * month_index + 2) / 5 + 1;
    let month = if month_index < 10 { month_index + 3 } else { month_index - 9 };
    let year = year_of_era + era * 400 + i64::from(month <= 2);

    (year, month, day)
}

// year, month from 1, day from 1 to days since 1970; civil_date the other way round
pub fn days_from_civil(year: i64, month: i64, day: i64) -> i64 {
    let year = if month <= 2 { year - 1 } else { year };
    let era = year.div_euclid(400);
    let year_of_era = year.rem_euclid(400);
    let shifted_month = (month + 9) % 12;
    let day_of_year = (153 * shifted_month + 2) / 5 + day - 1;
    let day_of_era = year_of_era * 365 + year_of_era / 4 - year_of_era / 100 + day_of_year;

    era * 146_097 + day_of_era - 719_468
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn twelve_hour_time_reads_like_a_wall_clock() {
        assert_eq!(twelve_hour(0), (String::from("12:00"), "AM"));
        assert_eq!(twelve_hour(9 * 3600 + 5 * 60), (String::from("9:05"), "AM"));
        assert_eq!(twelve_hour(12 * 3600), (String::from("12:00"), "PM"));
        assert_eq!(twelve_hour(16 * 3600 + 3 * 60 + 59), (String::from("4:03"), "PM"));
        assert_eq!(twelve_hour(23 * 3600 + 59 * 60), (String::from("11:59"), "PM"));
    }
}
