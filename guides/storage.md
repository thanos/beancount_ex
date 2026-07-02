# Storage

`beancount_ex` stores directives in a database via Ecto. The default backend is
SQLite in-memory (`:memory:`), which requires no configuration and runs in-process.
For persistence, configure a file path.

## Configuration

```elixir
# config/config.exs — default (in-memory)
config :beancount_ex, Beancount.Repo,
  database: ":memory:"

# For file persistence:
config :beancount_ex, Beancount.Repo,
  database: "path/to/ledger.db"
```

## Import and export

Import a `.bean` file into the database:

```elixir
{:ok, count} = Beancount.Storage.import_file("ledger.bean")
```

Export the database back to a `.bean` file:

```elixir
:ok = Beancount.Storage.export_file("out.bean")
```

Store a directive list directly:

```elixir
{:ok, count} = Beancount.Storage.store(directives)
```

Load all directives from the database:

```elixir
directives = Beancount.Storage.load()
```

Clear all directives:

```elixir
:ok = Beancount.Storage.clear()
```

## Schema overview

Each directive type maps to a database table under the `Beancount.Schemas`
namespace:

| Table | Schema | Key fields |
|-------|--------|------------|
| `beancount_opens` | `Schemas.Open` | date, account, currencies, booking |
| `beancount_closes` | `Schemas.Close` | date, account |
| `beancount_commodities` | `Schemas.Commodity` | date, currency |
| `beancount_transactions` | `Schemas.Transaction` | date, flag, payee, narration, postings (JSON) |
| `beancount_balances` | `Schemas.Balance` | date, account, amount, currency, tolerance |
| `beancount_prices` | `Schemas.Price` | date, commodity, amount, currency |
| `beancount_notes` | `Schemas.Note` | date, account, comment |
| `beancount_documents` | `Schemas.Document` | date, account, path |
| `beancount_events` | `Schemas.Event` | date, type, description |
| `beancount_customs` | `Schemas.Custom` | date, type, values (JSON) |
| `beancount_pads` | `Schemas.Pad` | date, account, source_account |
| `beancount_options` | `Schemas.Option` | name, value |
| ... | ... | ... |

Transaction postings are stored as a JSON column (`embeds_many`). Cost specs
are embedded within each posting. Metadata is stored as JSON (`:map`).

All tables include a `file_order` integer column that preserves source-file
ordering for deterministic rendering and round-trip fidelity.

## Future backends

- **PostgreSQL** (via `postgrex` + `ecto_sql`): durable, queryable, app-friendly.
  JSONB for metadata and postings. Window functions for running balances.
- **Mnesia** (via `ecto_mnesia`): distributed persistence without external
  services. ETS-backed RAM tables for fast access.
