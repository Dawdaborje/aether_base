# Currency

An [Aether](https://github.com/Dawdaborje) plugin written in Rhai: the plugin is the script `main.rhai`,
with nothing to compile.

## Files

| File | |
|---|---|
| `plugin.toml` | name, version, `capabilities`, `access_models`, `dependencies`, pages' app tile, commands, schedules |
| `main.rhai` | the functions; every public `fn` is callable |
| `models/<name>.json` | the plugin's data models (optional); `make sync` gives them their ids |
| `pages/*.xml` | the pages (optional) |

## Work on it

```sh
make                       # give the models ids, then register the plugin in the catalog
make install ORG=<org>     # install it for an organization
make upgrade ORG=<org>     # move an organization to the version you just loaded
```

`make` runs `aether --sync-models .` and `aether --load-plugin .`. Loading reads the script and refuses one that does
not compile. Set `CONFIG=path/to/aether.toml` when the configuration is not in the usual place. While developing,
`aether --serve --watch` loads and upgrades by itself whenever a file changes.

A plugin that links to another plugin's model (`"target": "currency.currency"`) needs that plugin loaded first;
list it under `dependencies`.

## Learn more

* `docs/plugin/rhai.md`: the language as Aether runs it, its limits and the commands a script can call.
* `docs/plugin/commands.md`: every kernel command, its capability and payload.
* `docs/plugin/pages.md` and `docs/plugin/cli-commands.md`: pages, and commands run with `aether --command`.
