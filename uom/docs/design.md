# Units of measure (`uom`)

## Purpose

Units grouped by what they measure (count, mass, length, …), each with one factor to the group’s reference unit and its own rounding. Products and stock convert quantities (and prices) only inside a group. Implemented in Rhai (`main.rhai`).

## Dependencies

none

## Models

| Model | Role |
|---|---|
| `uom_group` | Family of units: `code`, `name` |
| `uom` | Unit: `code`, `name`, group link, `factor` to reference, `decimals`, `is_reference`, `active` |

## Design

- Conversion is only allowed when `from.group == to.group`. Quantity: `qty * from.factor / to.factor`, rounded to the target unit’s `decimals` (0–8).
- `convert_price` is the inverse (price per `from` → price per `to`).
- Each group has exactly one reference unit (`factor` forced to `1`). Non-reference units require that reference to exist first. Factor must be greater than zero.
- Codes are lowercase, 1–30 characters. Seed is idempotent: groups `count`, `mass`, `length`, `volume`, `time` and common units (e.g. kg/g/t, m/cm, l/ml, hour/day).

## Functions, commands, events

**Commands:** `seed` → `seed_units`, `convert` → `convert`

**Public functions:** `create_group`, `create_unit`, `list_units`, `list_groups`, `convert`, `convert_price`, `seed_units`

**Events:** none

## Roles

none

## Boundaries

Does not own products, BOM, or inventory. Those plugins store a unit id/code and call `convert` / `convert_price`. Currencies and FX are `currency`, not UoM.
