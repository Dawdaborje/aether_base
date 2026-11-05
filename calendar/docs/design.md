# Holiday calendars (`calendar`)

## Purpose

Weekly days off and holidays, assignable over time to companies, branches, or people. Leave, attendance, and payroll ask which calendar applies and how many working days fall in a span. Implemented in Rust (WASM: `out/plugin.wasm`).

## Dependencies

- `country`
- `company`

## Models

| Model | Role |
|---|---|
| `holiday_calendar` | Name, optional country/company, weekend weekday list, `is_active` |
| `holiday` | Day on a calendar: name, kind (`public` / `optional` / `company`), half-day, recurring |
| `calendar_assignment` | Subject kind + id, calendar, `date_from` (effective from) |

## Design

- Weekend is a comma-separated weekday list (at most three days). Default used in span math when unset: `sat,sun`.
- Holidays are unique per calendar+date on create. Recurring holidays are projected into a requested year when listing.
- **Resolve:** callers pass an ordered list of subjects. The first subject that has any assignment wins. For that subject, use the latest assignment with `date_from <= day`; if the day is before every assignment, use the earliest (so a late-dated assignment still covers earlier days).
- **Working days:** weekends and `public`/`company` holidays are off; `optional` holidays still count as working; a half-day holiday subtracts 0.5 when that day would otherwise be working. Span queries capped at ten years.
- Assignments are unique per subject + start date (create fails on duplicate).

## Functions, commands, events

**Commands:** none declared in `plugin.toml`

**Exported handlers:** `create_calendar`, `update_calendar`, `list_calendars`, `create_holiday`, `remove_holiday`, `list_holidays`, `assign_calendar`, `list_assignments`, `resolve_calendar`, `calendar_span`, `calendar_working_days`

**Events:** none

## Roles

| Role | Meaning |
|---|---|
| `calendar_manager` | Creates calendars, holidays, and assignments |

## Boundaries

Does not own leave requests, attendance punches, or payroll calendars beyond answering “which calendar / how many working days”. Country and company records remain in `country` / `company`; this plugin only links to them.
