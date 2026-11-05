# Countries (`country`)

## Purpose

Reference data for countries (ISO 3166-1) and optional regions (states/provinces). Addresses, taxes, and shipping elsewhere link here. Each country may point at its usual currency in the `currency` plugin. Implemented in Rhai (`main.rhai`).

## Dependencies

- `currency`

## Models

| Model | Role |
|---|---|
| `country` | 2-letter `code`, optional 3-letter `code3`, name, phone prefix (`+` + digits), link to `currency`, `active` |
| `country_region` | Region under a country: `code`, `name` |

## Design

- Country codes are 2 letters; optional `code3` is 3 letters. Phone prefixes are `+` followed by digits (length 2–6).
- `currency_code` on create/update resolves via `currency.get_currency_by_code`; missing currency yields no link rather than inventing one.
- `seed_countries` is idempotent: African countries plus major world economies, each linked to a currency when that currency exists—run `currency.seed` first.
- Regions are additive (`add_region` / `remove_region`); uniqueness of region codes is enforced by create failures on duplicate keys as modeled.

## Functions, commands, events

**Commands:** `seed` → `seed_countries`

**Public functions:** `create_country`, `update_country`, `get_country`, `list_countries`, `add_region`, `list_regions`, `remove_region`, `seed_countries`

**Events:** none

## Roles

none

## Boundaries

Does not own parties, addresses, tax rules, or shipping. Holiday calendars may reference a country (`calendar`) but do not replace this catalog. Currencies themselves belong to `currency`.
