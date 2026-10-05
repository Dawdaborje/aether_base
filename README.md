# Aether Base

The business foundation that CRM, ERP, HR and the rest build on. Four plugins, written in Rhai, each one a
single `main.rhai` with its models and pages:

| Plugin | What it is | Depends on |
|---|---|---|
| `currency` | currencies, exchange rates against a base currency, conversion | none |
| `country` | countries (ISO 3166-1), phone prefixes, usual currencies, regions | `currency` |
| `party` | people and organizations: contacts, addresses, bank accounts, tags, duplicates | `currency`, `country` |
| `company` | the legal entities that keep the books: their party record, currency, fiscal year | `party`, `currency` |

How `party` and `company` fit together, what each function does and what is not built yet:
`aether/docs/architecture/party.md`.

## Using them

Plugins that link to another plugin's model must be loaded after it, and `--sync-models` needs the other plugin
already in the catalog (it copies the model's id into the link). From the Aether repository:

```sh
B=../plugins/base
aether --load-plugin $B/currency
aether --sync-models $B/country  && aether --load-plugin $B/country
aether --sync-models $B/party    && aether --load-plugin $B/party
aether --sync-models $B/company  && aether --load-plugin $B/company

aether --install-plugin company --org acme        # installs currency, country and party first
aether --command currency.seed --org acme         # 65 currencies; USD becomes the base
aether --command country.seed  --org acme         # 84 countries, each linked to its currency
aether --command company.create --org acme --arg name="Acme Ltd" --arg currency_code=USD
```

After editing a plugin, `aether --load-plugin` it again and `aether --upgrade-plugin <name> --org acme` (or run the
server with `--watch`, which does both).

## What is not here

Sequences (numbering), units of measure, products and mail were planned for this workspace and are not built.
The themes and the `attachment` plugin that were in this folder before are no longer here.
