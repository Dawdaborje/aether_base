# Aether Plugin API (v0.1 — evolving)

This document describes the **addon contract** used by `plugins/base` and expected by the kernel.
Fields and folders may grow; keep unknown keys so older addons stay loadable.

## Layout (recommended)

```text
my_addon/
  plugin.toml          # required manifest
  models/              # table / field definitions (.surql or .toml)
  migrations/          # ordered org-DB migrations for this addon
  pages/               # .xml UI pages
  components/          # reusable .xml fragments
  hooks/               # lifecycle + request hooks (stub handlers ok)
  events/              # emitted / consumed event declarations
  security/            # permission keys + default groups
  i18n/                # optional translation packs
  theme.json           # themes only
```

## `plugin.toml` shape

```toml
[plugin]
name = "partner"
label = "Partners"
version = "0.1.0"
description = "…"
dependencies = ["base_components"]   # plugin names; stored as graph edges in core DB
capabilities = ["db::query", "db::mutate"]
is_builtin = true

# Contract version this addon was written against.
[plugin.api]
version = "0.1"

# Optional kind: addon | theme | bridge_pack
[plugin.meta]
kind = "addon"
workspace = "base"

[[models]]
name = "partner"
table = "base_partner"
label = "Partner"
file = "./models/partner.surql"

[[pages]]
route = "/base/partners"
title = "Partners"
file = "./pages/partners.xml"
model = "base.partner"
view = "list"

[[menus]]
name = "partners"
label = "Contacts"
icon = "users"
url = "/base/partners"
order = 10
parent = "base_root"

[[hooks]]
# Future: WASM / rhai / lua handler ids. Declared early so the loader can validate.
name = "on_install"
phase = "install"          # install | upgrade | uninstall | request | cron
handler = "hooks.on_install"

[[hooks]]
name = "on_partner_write"
phase = "request"
event = "model.write"
model = "base.partner"
handler = "hooks.on_partner_write"

[[events]]
name = "partner.created"
direction = "emit"         # emit | listen
payload = "partner_id"

[[events]]
name = "mail.message_posted"
direction = "listen"
handler = "hooks.on_mail_message"

[[permissions]]
key = "partner.read"
label = "Read partners"

[[permissions]]
key = "partner.write"
label = "Create/update partners"

[communication]
# Future kernel channels this addon may use (email/sms/events).
channels = ["events", "email"]
```

## Stability rules

1. **Additive only** for a given `plugin.api.version` — don’t remove/rename required keys without bumping the API version.
2. Kernel must **ignore unknown sections** (forward compatible).
3. Pages stay **`.xml` only** (never `.ae`).
4. Dependencies are plugin **names**, resolved via Surreal `plugin_depends_on` graph.
5. Hooks/events may be declaration-only until the WASM host lands — still declare them.

## Communication (planned)

| Channel | Capability | Notes |
|---------|------------|--------|
| `events` | `events::emit` / `events::subscribe` | Cross-plugin bus |
| `email` | `email::send` | Via bridges |
| `sms` | `sms::send` | Via bridges |
| `http` | `http::request` | Allowlisted egress |
| `plugins` | `plugins::call` | RPC to another addon |

Declare intended channels under `[communication]` even before handlers exist.


## What may change (intentionally unstable)

Treat these as **declared early, implemented later** — shapes can grow:

| Area | Likely evolution |
|------|------------------|
| `[[pages]]` | includes/extends of shared XML, modal routes, action bindings |
| `plugin.toml` | more `[plugin.*]` sections; keep ignoring unknown keys |
| `[[hooks]]` | handler languages (WASM/rhai), filter expressions, priority |
| `[communication]` | typed channel configs, allowlists, rate limits |
| `[[events]]` | schema/versioned payloads, fan-out rules |
| `[[menus]]` | app launcher groups, ACL visibility expressions |
| Theme `[theme]` | multi-mode packs, density, chart palettes |

When the kernel enforces a new required field, bump `[plugin.api].version` and document the migration in this file.
