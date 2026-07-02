defmodule Beancount.Repo do
  @moduledoc """
  Ecto repository backing `Beancount.Storage` and `Beancount.Queries`.

  `Beancount.Repo` is a standard `Ecto.Repo` using the SQLite adapter
  (`Ecto.Adapters.SQLite3`). It is started under the application supervisor and
  auto-migrated on boot so tables are always ready — including for the default
  in-memory database, which is recreated on every process start.

  Most callers should use the higher-level APIs instead of touching the repo
  directly:

    * `Beancount.Storage` — store, load, import, and export directives
    * `Beancount.Queries` — canned Ecto queries over stored directives
    * `Beancount.Schemas` — schema overview and table mapping

  Use `Beancount.Repo` directly when you need custom `Ecto.Query` access beyond
  what `Beancount.Queries` provides.

  ## Configuration

  Default: SQLite in-memory (`:memory:`). No file is created; data lives for
  the duration of the OS process and is cleared on restart. **Keep `pool_size: 1`
  with `:memory:`** — each pooled connection gets its own empty database, so
  raising `pool_size` silently breaks `Storage`/`Queries`.

      config :beancount_ex, Beancount.Repo,
        database: ":memory:",
        pool_size: 1

  For a persistent ledger, point `:database` at a file path:

      config :beancount_ex, Beancount.Repo, database: "path/to/ledger.db"

  Add `Beancount.Repo` to `ecto_repos` in your config (already set in the
  default `config/config.exs`):

      config :beancount_ex, ecto_repos: [Beancount.Repo]

  ## Schema and tables

  One table per directive type. Each row stores the directive fields plus a
  `file_order` integer (zero-based source position). See `Beancount.Schemas`
  for the full schema-to-directive map.

  | Table | Schema |
  |-------|--------|
  | `beancount_opens` | `Beancount.Schemas.Open` |
  | `beancount_closes` | `Beancount.Schemas.Close` |
  | `beancount_commodities` | `Beancount.Schemas.Commodity` |
  | `beancount_transactions` | `Beancount.Schemas.Transaction` |
  | `beancount_balances` | `Beancount.Schemas.Balance` |
  | `beancount_prices` | `Beancount.Schemas.Price` |
  | `beancount_notes` | `Beancount.Schemas.Note` |
  | `beancount_documents` | `Beancount.Schemas.Document` |
  | `beancount_events` | `Beancount.Schemas.Event` |
  | `beancount_customs` | `Beancount.Schemas.Custom` |
  | `beancount_pads` | `Beancount.Schemas.Pad` |
  | `beancount_includes` | `Beancount.Schemas.Include` |
  | `beancount_options` | `Beancount.Schemas.Option` |
  | `beancount_plugins` | `Beancount.Schemas.Plugin` |
  | `beancount_push_tags` | `Beancount.Schemas.PushTag` |
  | `beancount_pop_tags` | `Beancount.Schemas.PopTag` |
  | `beancount_queries` | `Beancount.Schemas.Query` |

  The migration lives in `priv/repo/migrations/20260702000001_create_directives.exs`.

  ## Startup and migrations

  On application start, `Ecto.Migrator.run/3` applies all pending migrations.
  This is required for `:memory:` databases because the schema is lost when the
  process exits.

  ## Example: store via Storage, query via Repo

      import Ecto.Query
      alias Beancount.{Repo, Schemas}

      Beancount.Storage.store([
        Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"])
      ])

      Repo.all(from o in Schemas.Open, where: o.account == "Assets:Bank")
      # => [%Beancount.Schemas.Open{account: "Assets:Bank", ...}]

  ## Example: custom aggregation

      import Ecto.Query
      alias Beancount.{Repo, Schemas}

      Repo.aggregate(
        from(t in Schemas.Transaction, where: t.date >= ^~D[2026-01-01]),
        :count
      )
      # => 42

  ## Inherited functions

  This module `use`s `Ecto.Repo`, so all standard callbacks are available:
  `all/2`, `get/3`, `insert/2`, `update/2`, `delete/2`, `transaction/2`,
  `aggregate/3`, and others. See the [Ecto.Repo
  documentation](https://hexdocs.pm/ecto/Ecto.Repo.html).
  """

  use Ecto.Repo,
    otp_app: :beancount_ex,
    adapter: Ecto.Adapters.SQLite3
end
