# Aether Base Plugin Workspace

Business/UI foundation for Aether — **not** a kernel replacement.

Kernel facets own users, orgs, RBAC, sessions, settings, media storage, and the plugin registry.
This workspace owns shared XML, themes, and business primitives other suites depend on.

**Plugin API (evolving):** [docs/PLUGIN_API.md](./docs/PLUGIN_API.md)

## Addons

| Addon | Kind | Depends on |
|-------|------|------------|
| `base_components` | shared XML | — |
| `security_templates` | org permission seeds | `base_components` |
| `sequence` | document numbers | `base_components`, `security_templates` |
| `uom` | units of measure | `base_components`, `security_templates` |
| `currency` | currencies + rates | `base_components`, `security_templates` |
| `partner` | contacts | `base_components`, `security_templates`, `currency` |
| `mail` | chatter + activities | `base_components`, `security_templates` |
| `attachment` | link media ↔ records | `base_components`, `security_templates` |
| `product` | product master | `base_components`, `uom`, `currency`, `security_templates` |
| `company` | printable company profile | `base_components`, `currency`, `security_templates` |
| `theme_*` (6) | UI themes | `base_components` |

All addons are listed in [`workspace.toml`](./workspace.toml).

## Layout per addon

```text
addon/
  plugin.toml       # manifest ([plugin.api], models, pages, hooks, events, …)
  models/           # .surql table defs
  migrations/       # install-time org DB migrations
  pages/            # .xml pages
  components/       # reusable .xml
  hooks/            # lifecycle declarations
  events/           # emit/listen declarations
  security/         # permission keys
```

Unknown future keys in `plugin.toml` should be ignored by the loader (forward compatible).

## Suggested dependents

ERP / CRM / HRMS / LMS should depend on at least:

`base_components`, `security_templates`, `partner`, `sequence`, `currency`

(and `product` / `uom` / `mail` as needed).
