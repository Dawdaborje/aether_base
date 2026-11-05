# UI components (`base_ui`)

Components only. A plugin that uses them lists `base_ui` under `dependencies` and writes
`<use component="base_ui.…"/>`. The browser only sees built-in widget tags after expansion.

## Form chrome

| Component | Purpose |
|---|---|
| `status_bar` | Record state as steps; optional click calls a function |
| `form_bar` | Form buttons + Save + status steps for the page title bar |

```xml
<use component="base_ui.form_bar" field="stage" source="stages_of" function="set_stage">
  <button label="Mark won" function="win_deal" confirm="Mark this deal as won?"/>
  <button label="Back" href="/crm/deals" variant="outline"/>
</use>
```

See `docs/plugin/pages.md` ("The form's top bar"). Prefer these over hand-rolled `<header>`,
`<buttonbox>` and `<statusbar>` on workflow forms (CRM, helpdesk, HR).

## List helpers

| Component | Purpose |
|---|---|
| `empty_state` | `<empty title description/>` |
| `active_filter` | Active / Inactive filter (`field` defaults to `active`) |

```xml
<use component="base_ui.active_filter" field="is_active"/>
<use component="base_ui.empty_state" title="%no_company_yet%" description="%use_new_to_add%"/>
```

## Field blocks

| Component | Purpose |
|---|---|
| `contact_group` | Email + phone group; slot for mobile, website, name, … |
| `currency_link` | Code picker via `currency.list_currency_codes` |
| `party_link` | Party picker via `party.list_parties` |
| `company_link` | Company picker via `company.list_companies` |
| `date_range` | Start / end date pair |

```xml
<use component="base_ui.contact_group" title="%contact%">
  <field name="mobile" label="%mobile%"/>
</use>
<use component="base_ui.currency_link" label="%currency_code%"/>
<use component="base_ui.party_link" name="customer" label="Customer" required="true"/>
<use component="base_ui.company_link" required="true" label="Company"/>
<use component="base_ui.date_range" title="Dates"
     start="start_date" start_label="From" end="end_date" end_label="To"/>
```

CRM and ERP create forms should use `party_link` and `company_link` instead of repeating the
same `source` / `optionLabel` / `entity` attributes.

## Related list

| Component | Purpose |
|---|---|
| `related_list` | Titled group; put the child `<view type="list">` in the slot |

The list `model` must belong to the page's plugin, so it cannot be a prop here.

```xml
<use component="base_ui.related_list" title="Leave">
  <view type="list" model="leave_request" source="employee_leave_requests">
    <columns>
      <column field="start_date" label="From" fieldType="date"/>
      <column field="state" label="State" fieldType="badge"/>
    </columns>
    <empty title="No leave yet" description="Leave requests appear here."/>
  </view>
</use>
```

HRMS employee panels and helpdesk notebook lists can wrap this instead of copying the group shell.
