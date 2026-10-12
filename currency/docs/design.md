# Currencies (`currency`)

## Purpose

Owns currencies and exchange rates for business documents. Rates are always against one base currency; other plugins call `convert` instead of storing their own FX tables. Implemented as a single Rhai script (`main.rhai`).

## Dependencies

none

## Models

| Model | Role |
|---|---|
| `currency` | ISO-style code (3 letters), name, symbol, decimal places, `is_base`, `active` |
| `currency_rate` | Dated rate for a non-base currency: units of that currency per one unit of the base |

## Design

- Exactly one base currency at a time (`is_base`). `set_base` clears the previous base in a transaction; the base is always active.
- A rate means “units of this currency for one unit of the base”. The base’s effective rate is always `1`; `set_rate` refuses the base currency.
- Conversion on a date uses the newest rate on or before that date for each side: `amount / rate(from) * rate(to)`, rounded to the target’s `decimal_places` (0–6).
- Currency codes are three uppercase letters. Seed creates ~65 common currencies (idempotent); the first seed with no base makes USD the base.
- Emits `rate_changed` with `{ code, rate, date }` when a rate is set or updated for a date.

## Functions, commands, events

**Commands:** `seed` → `seed_currencies`

**Public functions:** `create_currency`, `update_currency`, `get_currency_by_code`, `get_currency`, `list_currencies`, `set_active`, `get_base`, `set_base`, `set_rate`, `get_rate`, `list_rates`, `convert`, `seed_currencies`

**Events:** `rate_changed`

## Roles

none

## Boundaries

Does not own countries, companies, or documents that *use* a currency—only the currency catalog and FX against the base. Country “usual currency” links live in `country`; a company’s working currency lives in `company`.
