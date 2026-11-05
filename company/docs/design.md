# Companies (`company`)

## Purpose

Legal entities that issue documents and keep the books inside an organization. Identity fields (name, tax id, addresses, banks) live on a linked `party` organization; this plugin adds currency, fiscal year start, default flag, and logo. Implemented in Rhai (`main.rhai`).

## Dependencies

- `party`
- `currency`

## Models

| Model | Role |
|---|---|
| `company` | `name`, link to `party`, link to `currency`, fiscal year start month/day, `logo_url`, `is_default`, `is_active` |

## Design

- `create_company` validates fiscal start and currency *before* creating the party, then creates an organization party (`is_customer: false`) and the company row. Name uniqueness among companies.
- The first company (or an explicit `is_default`) becomes the default; `set_default_company` clears other defaults in a transaction. An archived company cannot be default; the default cannot be archived until another is set.
- Updating name/tax/email/phone/website goes through `party.update_party`; currency and fiscal fields stay on `company`.
- `fiscal_year` returns inclusive `{ start, end }` for a date (default company if no id). Fiscal years starting on 29 Feb use 28 Feb in non-leap years; the year ends the day before the next start.
- Several companies per org are allowed; scoping other plugins’ rows by company is their responsibility.

## Functions, commands, events

**Commands:** `create` → `create_company` (args: `name`, optional `currency_code`, `tax_id`, `email`, `phone`, fiscal start)

**Public functions:** `create_company`, `update_company`, `get_company`, `list_companies`, `get_default_company`, `set_default_company`, `archive_company`, `fiscal_year`

**Events:** none

## Roles

none

## Boundaries

Does not own party contact graphs, currencies, holiday calendars, or multi-company document scoping. Branches/sites and accounting charts belong elsewhere. Calendar assignments may target a company id but live in `calendar`.

## Default company (seed)

`seed` (`seed_default_company`, run on install and on upgrade) creates one company named after the
organization when the organization has none, in the base currency when the currency plugin has one. It
does nothing when any company exists, so it is safe to repeat and never replaces a company made by hand.
Legal details (tax number, address, fiscal year) are left for an administrator to complete. The first
company becomes the default one, as `create_company` already does. Run it again with
`aether --command company.seed --org <organization>`.
