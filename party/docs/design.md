# Parties (`party`)

## Purpose

One business-identity record for every person or organization the tenant deals with (customers, suppliers, employees’ contacts, banks). CRM, accounting, and HR link to a party instead of copying name/email. Kernel login accounts are separate; `user` on a party is an optional link. Implemented in Rhai (`main.rhai`).

## Dependencies

- `currency`
- `country`

## Models

| Model | Role |
|---|---|
| `party` | Person or organization: contact fields, tax id, currency, role flags, optional parent org, optional `user`, `is_active` |
| `party_address` | Address lines, region, country, default flag, optional geo |
| `party_bank_account` | Bank details (sensitive; not included in `get_party_details`) |
| `party_tag` | Named tag with color |
| `party_tag_link` | Assignment of a tag to a party |

## Design

- Kind is `person` or `organization`. A person may have `parent` only if the parent is an organization (org contacts).
- Role flags (`is_customer`, `is_supplier`, `is_employee`, `is_bank`) are filters, not separate tables. Other plugins add domain data by linking to the party id.
- Records are not deleted in normal flows—only archived. Archiving an org with active contacts requires `with_contacts` (or move them first).
- Tax id uniqueness among parties; email/phone normalized (email lowercased; phone international `+` + digits). Display name for a person under an org is `Name (Org)`.
- Bank accounts are listed separately from `get_party_details` (addresses + tags only).
- **Merge** moves addresses, bank accounts, child contacts, and tags onto the survivor; fills blank fields and OR’s role flags; archives the duplicate with a note; emits `merged` so *other* plugins must repoint their own FKs. Nothing is hard-deleted. Same kind only; survivor must be active.
- `find_duplicates` groups active parties sharing tax id, email, or phone.

## Functions, commands, events

**Commands:** `merge`, `find_duplicates`

**Public functions (selected):** `create_person`, `create_organization`, `update_party`, `get_party`, `get_party_details`, `archive`, `unarchive`, `link_user`, `search` / `list_parties`, `find_duplicates`, address/bank/tag helpers, `merge`

**Events:** `created`, `updated`, `archived`, `merged` (`{ from, into, kind }`)

## Roles

none

## Boundaries

Does not own legal-entity books (`company`), login/RBAC (kernel auth), invoices, or CRM pipelines. Company name/tax/addresses live on the company’s linked party; fiscal year and default company live on `company`.
