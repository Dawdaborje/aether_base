# Aether Base

Always-installed foundation workspace for Aether. Kernel facets own identity, tenancy, and RBAC; this workspace owns the business primitives that CRM, ERP, HRMS, and similar domains link to instead of reinventing.

## Features

- Currencies with a single base and dated FX rates
- ISO countries (and regions) tied to a usual currency
- Parties as shared people/org identity (contacts, addresses, banks, tags, merge)
- Companies as legal entities wrapping a party plus fiscal year / default
- Holiday calendars with time-based assignment and working-day math
- Document number sequences (per-period counters, optional gapless audit)
- Units of measure grouped by dimension with conversion and per-unit rounding

## Plugins

| Name | Purpose | Depends on | Design |
|---|---|---|---|
| `currency` | Currencies and exchange rates against one base | — | [docs](./currency/docs/design.md) |
| `country` | Countries (ISO 3166-1), phone prefixes, regions | `currency` | [docs](./country/docs/design.md) |
| `party` | People and organizations: contacts, addresses, banks, tags, duplicates | `currency`, `country` | [docs](./party/docs/design.md) |
| `company` | Legal entities: party link, currency, fiscal year, default | `party`, `currency` | [docs](./company/docs/design.md) |
| `calendar` | Holiday calendars, weekends, assignments, working days | `country`, `company` | [docs](./calendar/docs/design.md) |
| `number_sequence` | Document numbers with prefixes, resets, gapless audit | — | [docs](./number_sequence/docs/design.md) |
| `uom` | Units by measure group, factor to reference, conversion | — | [docs](./uom/docs/design.md) |

Declared in `workspace.toml` under `[workspace.plugins]`. Folders such as `attachment` / `base_components` in this tree are not workspace plugins.

## Suggested load / install order

Plugins that link to another plugin’s model must load after it (`--sync-models` needs the target already in the catalog):

1. `currency`
2. `country`
3. `party`
4. `company`
5. `calendar`
6. `number_sequence` and `uom` (no dependencies; any time after catalog setup)

Example from the Aether repo:

```sh
B=../plugins/base
aether --load-plugin $B/currency
aether --sync-models $B/country  && aether --load-plugin $B/country
aether --sync-models $B/party    && aether --load-plugin $B/party
aether --sync-models $B/company  && aether --load-plugin $B/company
aether --sync-models $B/calendar && aether --load-plugin $B/calendar
aether --load-plugin $B/number_sequence
aether --load-plugin $B/uom

aether --install-plugin company --org acme   # pulls currency, country, party first
aether --command currency.seed --org acme
aether --command country.seed  --org acme
aether --command uom.seed      --org acme
```

## Relation to CRM / ERP / HRMS

These plugins are foundation only: shared currency, geography, party identity, legal entity, calendars, numbering, and units. Domain workspaces (CRM pipelines, accounting, leave/payroll, inventory) depend on them and must not duplicate those catalogs. Login accounts and RBAC stay in the kernel; a party may optionally link to a user.
