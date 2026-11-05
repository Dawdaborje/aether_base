# Number sequences (`number_sequence`)

## Purpose

Document numbers with optional date tokens in the prefix/suffix, a counter per reset period, and optional gapless issue records so missing numbers can be audited. Other plugins call `next_number` (or the `next` command). Implemented in Rhai (`main.rhai`).

## Dependencies

none

## Models

| Model | Role |
|---|---|
| `number_sequence` | Code, label, prefix/suffix, padding, start/step, reset (`never`/`year`/`month`), optional scope, `gapless`, `active`, unique `key` |
| `number_counter` | One row per sequence+period (`key` = `seq.key|period`), field `last` incremented atomically |
| `number_issue` | Gapless audit row: value, formatted number, reference, `state` (`issued` / `void`), void reason |

## Design

- Sequence `key` is `code` or `code@scope`. A scoped lookup falls back to the unscoped sequence if no scoped row exists.
- Reset periods: `all`, `YYYY`, or `YYYY-MM`. Each period gets its own counter row so yearly/monthly reset never races an old counter; increment uses the kernel’s atomic `db::increment`.
- Prefix/suffix may contain `{YYYY}`, `{YY}`, `{MM}`, `{DD}` filled from the document date (today if omitted).
- Gapless sequences create a `number_issue` on each `next_number`. Failed documents should call `void_number` with a reason; `audit_gaps` lists values between first and last issued that were never recorded.
- Codes are lowercase letters, digits, `_`, `.`, `-` (1–60 chars).

## Functions, commands, events

**Commands:** `create` → `create_sequence`, `next` → `next_number`, `audit` → `audit_gaps`

**Public functions:** `create_sequence`, `get_sequence`, `list_sequences`, `next_number`, `peek_number`, `void_number`, `audit_gaps`

**Events:** none

Typical invoke: `plugins::invoke("number_sequence", "next_number", #{ code: "inv", date: "2026-10-05" })`

## Roles

none

## Boundaries

Does not own the documents that consume numbers (invoices, employees, journals). Those plugins define sequences and call `next_number` / void on failure. Not the same as kernel field-level sequences used inside model definitions.
