use amane::{Center, Column, End, Rectangle, Row, Text, Weight, Widget};

use crate::clock::{civil_date, days_from_civil};
use crate::theme::{MONO, Theme, dash, size};

const HEADER: [&str; 7] = ["mo", "tu", "we", "th", "fr", "sa", "su"];

// the month around a day: where it starts in the week, how long it is, and which day that is
#[derive(Debug, PartialEq)]
pub struct Month {
    // 0 is monday
    pub first_weekday: usize,
    pub length: i64,
    pub today: i64,
}

pub fn month(days: i64) -> Month {
    let (year, month, day) = civil_date(days);

    Month {
        first_weekday: weekday(days - (day - 1)),
        length: length(year, month),
        today: day,
    }
}

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

fn length(year: i64, month: i64) -> i64 {
    match month {
        2 if is_leap(year) => 29,
        2 => 28,
        4 | 6 | 9 | 11 => 30,
        _ => 31,
    }
}

fn is_leap(year: i64) -> bool {
    year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

/*
 * the month as seven right-aligned columns under the weekday names, monday
 * first. today is the one bright, bold number, with a line under it
 */
pub fn view(days: i64, theme: &Theme) -> Column {
    let month = month(days);

    let cell_size = (dash::CALENDAR / 7.0, size::SM * 1.5);

    let small = |text: String, color| Text::new(text).font(MONO).size(size::SM).color(color);

    let header: Vec<Box<dyn Widget>> = HEADER
        .iter()
        .map(|name| cell(small(name.to_string(), theme.outline), cell_size))
        .collect();

    let mut rows: Vec<Box<dyn Widget>> = vec![Box::new(Row::new(header))];

    // the days before the first, in last month
    let mut week: Vec<Box<dyn Widget>> = (0..month.first_weekday)
        .map(|_| cell(small(String::new(), theme.outline), cell_size))
        .collect();

    for day in 1..=month.length {
        let number = if day == month.today {
            let text = small(day.to_string(), theme.on_surface).weight(Weight::Bold);

            let underline = Rectangle::new()
                .width(Widget::width(&text))
                .height(dash::UNDERLINE)
                .fill(theme.on_surface);

            cell(
                Column::new(vec![Box::new(text), Box::new(underline)]).align(End),
                cell_size,
            )
        } else {
            cell(small(day.to_string(), theme.on_surface_variant), cell_size)
        };

        week.push(number);

        if week.len() == 7 {
            rows.push(Box::new(Row::new(std::mem::take(&mut week))));
        }
    }

    if !week.is_empty() {
        rows.push(Box::new(Row::new(week)));
    }

    Column::new(rows).gap(dash::CALENDAR_ROW_GAP)
}

// one day's place in the grid, its number against the right edge
fn cell<W: Widget + 'static>(child: W, (width, height): (f32, f32)) -> Box<dyn Widget> {
    Box::new(
        Rectangle::new()
            .width(width)
            .height(height)
            .align_child(End, Center)
            .child(child),
    )
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
    fn lays_out_the_month() {
        assert_eq!(
            month(day(2026, 11, 10)),
            Month {
                first_weekday: 6,
                length: 30,
                today: 10
            }
        );

        assert_eq!(month(day(2024, 2, 1)).length, 29);
        assert_eq!(month(day(2100, 2, 1)).length, 28);
        assert_eq!(month(day(2000, 2, 1)).length, 29);
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
