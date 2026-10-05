//! Holiday calendars: which days an organization, a branch or a person does not work.
//!
//! Following what Frappe and ERPNext do well: a calendar owns its weekly days off, holidays have a
//! kind (public, optional, company) and may be half days, and calendars are **assigned over time**
//! (the one in force on a day is the latest assigned on or before it), with a more specific subject
//! (a person) winning over a general one (their company). Following Odoo: a calendar can belong to a
//! country. Other plugins ask `resolve_calendar` which calendar applies to someone, and
//! `calendar_span` what its days off are; they do the counting.

use aether_sdk::dates::{self, format_date, holiday_dates, parse_date, Calendar, Datelike, HolidayRow, NaiveDate};
use aether_sdk::db::Filter;
use aether_sdk::prelude::*;
use aether_sdk::records::{pick, require, text, today, Record};

#[derive(Deserialize)]
struct Id {
    id: String,
}

#[derive(Deserialize)]
struct Change {
    id: String,
    #[serde(flatten)]
    fields: Record,
}

#[derive(Deserialize)]
struct Listing {
    calendar: String,
    /// Show the holidays as they fall in this year (recurring ones included).
    #[serde(default)]
    year: Option<i32>,
}

#[derive(Deserialize)]
struct Assign {
    subject_kind: String,
    subject: String,
    calendar: String,
    date_from: String,
}

#[derive(Deserialize)]
struct Subject {
    kind: String,
    id: String,
}

#[derive(Deserialize)]
struct Resolve {
    /// Most specific first: the person, then their branch, then their company.
    subjects: Vec<Subject>,
    #[serde(default)]
    on: Option<String>,
}

#[derive(Deserialize)]
struct Span {
    calendar: String,
    from: String,
    to: String,
}

fn check_weekend(weekend: &str) -> Result<Vec<String>> {
    let days: Vec<String> = weekend.split(',').map(|d| d.trim().to_lowercase()).filter(|d| !d.is_empty()).collect();
    if days.len() > 3 {
        return Err(Error::msg("a weekend of more than three days leaves little to work"));
    }
    dates::weekdays(&days)?;
    Ok(days)
}

fn new_calendar(input: Record) -> Result<Record> {
    if text(&input, "name").is_none() {
        return Err(Error::msg("a calendar needs a name"));
    }
    let mut data = pick(&input, &["name", "country", "company", "weekend", "is_active"]);
    if let Some(weekend) = text(&data, "weekend") {
        data["weekend"] = json!(check_weekend(weekend)?.join(","));
    }
    db::create("holiday_calendar", &data).map_err(|e| e.or("could not create the calendar (the name may be taken)"))
}

fn change_calendar(input: Change) -> Result<Record> {
    require("holiday_calendar", &input.id, "calendar")?;
    let mut data = pick(&input.fields, &["name", "country", "company", "weekend", "is_active"]);
    if data.as_object().is_some_and(|f| f.is_empty()) {
        return Err(Error::msg("there is nothing to change"));
    }
    if let Some(weekend) = text(&data, "weekend") {
        data["weekend"] = json!(check_weekend(weekend)?.join(","));
    }
    db::update::<Record>("holiday_calendar", &input.id, &data)?.ok_or_else(|| Error::msg("the calendar is gone"))
}

fn new_holiday(input: Record) -> Result<Record> {
    let calendar = text(&input, "calendar").ok_or_else(|| Error::msg("a holiday belongs to a calendar"))?;
    require("holiday_calendar", calendar, "calendar")?;
    if text(&input, "name").is_none() {
        return Err(Error::msg("a holiday needs a name"));
    }
    let date = parse_date(text(&input, "date").ok_or_else(|| Error::msg("a holiday needs a date"))?)?;
    if let Some(kind) = text(&input, "kind") {
        if !["public", "optional", "company"].contains(&kind) {
            return Err(Error::msg("kind is public, optional or company"));
        }
    }
    let mut data = pick(&input, &["calendar", "name", "kind", "is_half_day", "recurring"]);
    data["date"] = json!(format_date(date));
    db::create("holiday", &data).map_err(|e| e.or("that calendar already has a holiday on that date"))
}

/// A calendar's holidays; with a year, as they fall in that year.
fn holidays(input: Listing) -> Result<Vec<Record>> {
    let rows: Vec<Record> = db::find::<Record>("holiday").filter("calendar", input.calendar.as_str()).order_by("date").limit(1000).all()?;
    let Some(year) = input.year else { return Ok(rows) };
    let mut out = Vec::new();
    for mut row in rows {
        let date = parse_date(text(&row, "date").unwrap_or_default())?;
        if date.year() == year {
            out.push(row);
        } else if row.get("recurring") == Some(&json!(true)) {
            if let Some(shown) = NaiveDate::from_ymd_opt(year, date.month(), date.day()) {
                row["date"] = json!(format_date(shown));
                out.push(row);
            }
        }
    }
    out.sort_by(|a, b| text(a, "date").cmp(&text(b, "date")));
    Ok(out)
}

fn assign(input: Assign) -> Result<Record> {
    require("holiday_calendar", &input.calendar, "calendar")?;
    if input.subject_kind.trim().is_empty() || input.subject.trim().is_empty() {
        return Err(Error::msg("say what the calendar is for"));
    }
    let from = parse_date(&input.date_from)?;
    db::create(
        "calendar_assignment",
        &json!({ "subject_kind": input.subject_kind, "subject": input.subject, "calendar": input.calendar, "date_from": format_date(from) }),
    )
    .map_err(|e| e.or("that subject already has an assignment starting that day"))
}

/// The calendar in force for the first subject that has one. Within a subject, the latest
/// assignment starting on or before the day; a day before the first assignment uses the earliest
/// (Frappe does the same, so nobody is left without a calendar by an assignment dated too late).
fn resolve(input: Resolve) -> Result<Value> {
    let on = match &input.on {
        Some(day) => format_date(parse_date(day)?),
        None => today()?,
    };
    for subject in &input.subjects {
        let latest = db::find::<Record>("calendar_assignment")
            .matching(
                Filter::eq("subject_kind", subject.kind.as_str())
                    .and(Filter::eq("subject", subject.id.as_str()))
                    .and(Filter::lte("date_from", on.as_str())),
            )
            .order_by("-date_from")
            .first()?;
        let found = match latest {
            Some(found) => Some(found),
            None => db::find::<Record>("calendar_assignment")
                .matching(Filter::eq("subject_kind", subject.kind.as_str()).and(Filter::eq("subject", subject.id.as_str())))
                .order_by("date_from")
                .first()?,
        };
        if let Some(found) = found {
            return Ok(json!({ "calendar": found["calendar"], "source": subject.kind, "from": found["date_from"] }));
        }
    }
    Ok(json!({ "calendar": null }))
}

/// The weekend and the holidays of a calendar between two days (inclusive), for counting working days.
fn span(input: Span) -> Result<Value> {
    let calendar = require("holiday_calendar", &input.calendar, "calendar")?;
    let (from, to) = (parse_date(&input.from)?, parse_date(&input.to)?);
    if to < from {
        return Err(Error::msg("the period ends before it starts"));
    }
    if (to - from).num_days() > 3660 {
        return Err(Error::msg("ask for at most ten years at a time"));
    }
    let weekend = check_weekend(text(&calendar, "weekend").unwrap_or("sat,sun"))?;
    let rows: Vec<Record> = db::find::<Record>("holiday").filter("calendar", input.calendar.as_str()).limit(1000).all()?;
    let mut out = Vec::new();
    for row in rows {
        let date = parse_date(text(&row, "date").unwrap_or_default())?;
        let recurring = row.get("recurring") == Some(&json!(true));
        let dates = holiday_dates(&[HolidayRow { date, recurring }], from.year(), to.year());
        for day in dates.into_iter().filter(|day| *day >= from && *day <= to) {
            out.push(json!({
                "date": format_date(day), "name": row["name"], "kind": row.get("kind").cloned().unwrap_or(json!("public")),
                "is_half_day": row.get("is_half_day").cloned().unwrap_or(json!(false)),
            }));
        }
    }
    out.sort_by(|a, b| a["date"].as_str().cmp(&b["date"].as_str()));
    Ok(json!({ "weekend": weekend, "holidays": out }))
}

/// Working days in a period by the calendar: weekends and public and company holidays are off;
/// optional holidays are working days; a half-day holiday counts as half.
fn working_days(input: Span) -> Result<Value> {
    let (from, to) = (parse_date(&input.from)?, parse_date(&input.to)?);
    let spans = span(Span { calendar: input.calendar, from: input.from, to: input.to })?;
    let weekend = dates::weekdays(&spans["weekend"].as_array().cloned().unwrap_or_default().iter().filter_map(|d| d.as_str().map(str::to_string)).collect::<Vec<_>>())?;
    let mut calendar = Calendar { weekend, holidays: Vec::new() };
    let mut halves = 0u32;
    for holiday in spans["holidays"].as_array().cloned().unwrap_or_default() {
        if holiday["kind"] == "optional" {
            continue;
        }
        let Some(day) = holiday["date"].as_str().and_then(|d| parse_date(d).ok()) else { continue };
        if holiday["is_half_day"] == true {
            if calendar.is_working_day(day) {
                halves += 1;
            }
        } else {
            calendar.holidays.push(day);
        }
    }
    let whole = calendar.working_days(from, to);
    // A half-day holiday takes half a day off the total.
    let days = aether_sdk::decimal::Decimal::whole(i64::from(whole), 2)? - aether_sdk::decimal::Decimal::parse("0.5")?.with_scale(2)?.times_ratio(i64::from(halves), 1)?;
    Ok(json!({ "days": days }))
}

handler! {
    fn create_calendar(input: Record) -> Record {
        new_calendar(input)
    }

    fn update_calendar(input: Change) -> Record {
        change_calendar(input)
    }

    fn list_calendars(_: Empty) -> Vec<Record> {
        db::find("holiday_calendar").order_by("name").limit(200).all()
    }

    fn create_holiday(input: Record) -> Record {
        new_holiday(input)
    }

    fn remove_holiday(input: Id) -> Option<Record> {
        db::delete("holiday", &input.id)
    }

    fn list_holidays(input: Listing) -> Vec<Record> {
        holidays(input)
    }

    /// Say which calendar a company, branch or person uses from a day.
    fn assign_calendar(input: Assign) -> Record {
        assign(input)
    }

    fn list_assignments(input: Id) -> Vec<Record> {
        db::find("calendar_assignment").filter("calendar", input.id.as_str()).order_by("-date_from").limit(500).all()
    }

    /// The calendar in force for the first of the subjects that has one.
    fn resolve_calendar(input: Resolve) -> Value {
        resolve(input)
    }

    /// The weekend and holidays of a calendar between two days.
    fn calendar_span(input: Span) -> Value {
        span(input)
    }

    fn calendar_working_days(input: Span) -> Value {
        working_days(input)
    }
}
