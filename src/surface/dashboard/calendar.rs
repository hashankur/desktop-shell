use crate::clock::{civil_date, days_from_civil};

// 0 is monday; 1970-01-01 was a thursday
pub fn weekday(days: i64) -> usize {
    (days + 3).rem_euclid(7) as usize
}

/*
 * the iso week and the year it belongs to: weeks start on monday, and the
 * first week of a year is the one with its thursday in it, so the last days
 * of december can be week 1 of the next year and the first of january week
 * 52 or 53 of the last
 */
pub fn iso_week(days: i64) -> (i64, i64) {
    let thursday = days - weekday(days) as i64 + 3;

    let (year, _, _) = civil_date(thursday);

    (year, (thursday - days_from_civil(year, 1, 1)) / 7 + 1)
}

#[cfg(test)]
mod tests {
    use super::*;

    // the dates checked against `date -d <day> '+%G %V %u'`
    fn day(year: i64, month: i64, day: i64) -> i64 {
        days_from_civil(year, month, day)
    }

    #[test]
    fn counts_days_the_same_way_both_ways() {
        assert_eq!(day(1970, 1, 1), 0);

        for days in [-1, 0, 59, 20_402, 20_767, 50_000] {
            let (year, month, date) = civil_date(days);

            assert_eq!(day(year, month, date), days);
        }
    }

    #[test]
    fn knows_the_weekday() {
        assert_eq!(weekday(day(2026, 11, 10)), 1);
        assert_eq!(weekday(day(2026, 11, 1)), 6);
        assert_eq!(weekday(day(2027, 1, 4)), 0);
    }

    #[test]
    fn iso_weeks_cross_the_year_like_date_says() {
        assert_eq!(iso_week(day(2026, 11, 10)), (2026, 46));
        assert_eq!(iso_week(day(2026, 11, 1)), (2026, 44));
        assert_eq!(iso_week(day(2026, 12, 31)), (2026, 53));
        assert_eq!(iso_week(day(2027, 1, 1)), (2026, 53));
        assert_eq!(iso_week(day(2027, 1, 4)), (2027, 1));
        assert_eq!(iso_week(day(2024, 2, 1)), (2024, 5));
        assert_eq!(iso_week(day(2021, 1, 3)), (2020, 53));
        assert_eq!(iso_week(day(2020, 12, 31)), (2020, 53));
    }
}
