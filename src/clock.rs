use std::time::{Duration, SystemTime, UNIX_EPOCH};

use amane::Service;

// the offset is asked for again every 10 minutes, to follow daylight saving changes
const OFFSET_REFRESH: u32 = 600;

const SECONDS_PER_DAY: i64 = 24 * 60 * 60;

// 1970-01-01 was a thursday
const WEEKDAYS: [&str; 7] = ["THU", "FRI", "SAT", "SUN", "MON", "TUE", "WED"];

const MONTHS: [&str; 12] = [
    "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC",
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

    // the bar's readout, like "SUN 09 NOV 🞄 03:49 PM"
    pub fn readout(&self) -> String {
        let days = self.local.div_euclid(SECONDS_PER_DAY);
        let today = self.local.rem_euclid(SECONDS_PER_DAY);

        let weekday = WEEKDAYS[days.rem_euclid(7) as usize];
        let (_, month, day) = civil_date(days);
        let month = MONTHS[(month - 1) as usize];

        let hours = today / 3600;
        let minutes = today % 3600 / 60;

        let period = if hours < 12 { "AM" } else { "PM" };

        // 0 and 12 both read as 12
        let hours = match hours % 12 {
            0 => 12,
            hours => hours,
        };

        format!("{weekday} {day:02} {month} 🞄 {hours:02}:{minutes:02} {period}")
    }
}

// `date +%z` prints like +0530; anything unreadable counts as utc
fn read_offset() -> i64 {
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
fn civil_date(days: i64) -> (i64, i64, i64) {
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
