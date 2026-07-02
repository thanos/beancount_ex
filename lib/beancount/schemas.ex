defmodule Beancount.Schemas do
  @moduledoc """
  Ecto schemas for persisting Beancount directives.

  These schemas are the storage-layer counterpart of the `Beancount.Directives.*`
  structs. `Beancount.Storage.store/1` converts each directive into the matching
  schema and inserts it; `Beancount.Storage.load/0` reads the rows back and
  rebuilds the original directive structs.

  Each dated directive is stored in its own table and carries a `file_order`
  integer that records the directive's zero-based position in the original
  source, so the ledger can be reconstructed in its authored order.

  ## Schema to directive map

  | Schema | Directive | Table |
  |--------|-----------|-------|
  | `Beancount.Schemas.Open` | `Beancount.Directives.Open` | `beancount_opens` |
  | `Beancount.Schemas.Close` | `Beancount.Directives.Close` | `beancount_closes` |
  | `Beancount.Schemas.Commodity` | `Beancount.Directives.Commodity` | `beancount_commodities` |
  | `Beancount.Schemas.Transaction` | `Beancount.Directives.Transaction` | `beancount_transactions` |
  | `Beancount.Schemas.Balance` | `Beancount.Directives.Balance` | `beancount_balances` |
  | `Beancount.Schemas.Price` | `Beancount.Directives.Price` | `beancount_prices` |
  | `Beancount.Schemas.Note` | `Beancount.Directives.Note` | `beancount_notes` |
  | `Beancount.Schemas.Document` | `Beancount.Directives.Document` | `beancount_documents` |
  | `Beancount.Schemas.Event` | `Beancount.Directives.Event` | `beancount_events` |
  | `Beancount.Schemas.Custom` | `Beancount.Directives.Custom` | `beancount_customs` |
  | `Beancount.Schemas.Pad` | `Beancount.Directives.Pad` | `beancount_pads` |
  | `Beancount.Schemas.Include` | `Beancount.Directives.Include` | `beancount_includes` |
  | `Beancount.Schemas.Option` | `Beancount.Directives.Option` | `beancount_options` |
  | `Beancount.Schemas.Plugin` | `Beancount.Directives.Plugin` | `beancount_plugins` |
  | `Beancount.Schemas.PushTag` | `Beancount.Directives.PushTag` | `beancount_push_tags` |
  | `Beancount.Schemas.PopTag` | `Beancount.Directives.PopTag` | `beancount_pop_tags` |
  | `Beancount.Schemas.Query` | `Beancount.Directives.Query` | `beancount_queries` |

  `Beancount.Schemas.Posting` and `Beancount.Schemas.CostSpec` are embedded
  schemas nested inside `Beancount.Schemas.Transaction`; they have no table of
  their own.

  ## Example

      Beancount.Storage.store([Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"])])
      [%Beancount.Directives.Open{account: "Assets:Bank"}] = Beancount.Storage.load()

  """
end
