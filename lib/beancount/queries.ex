defmodule Beancount.Queries do
  @moduledoc """
  Ecto.Query-based queries against stored Beancount directives.

  These functions read directly from the database tables populated by
  `Beancount.Storage` — no booking engine or BQL required. They return
  `Beancount.Schemas.*` rows (the storage layer), not `Beancount.Directives.*`
  structs. To work with directive structs, call `Beancount.Storage.load/0`
  instead.

  For balance reports that need inventory booking and cost-lot logic, use
  `Beancount.Report` (which dispatches BQL through the configured engine).

  ## Prerequisites

  Data must be stored before querying:

      Beancount.Storage.import_file("ledger.bean")
      # or
      Beancount.Storage.store(directives)

  ## Public functions

  | Function | Description |
  |----------|-------------|
  | `list_opens/1` | Open directives, optionally filtered by account prefix |
  | `list_closes/0` | All close directives |
  | `count_transactions_by_date/0` | Transaction counts grouped by date |
  | `find_transactions/1` | Transactions filtered by payee, narration, date range |
  | `list_prices/1` | Price directives for one commodity |
  | `list_balances/1` | Balance assertions for one account |
  | `count_by_type/0` | Row counts per directive table |

  ## Example: filter and aggregate

      Beancount.Storage.store([
        Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
        Beancount.open(~D[2026-01-01], "Assets:Cash", ["USD"]),
        Beancount.transaction(~D[2026-01-15], "*", "Employer", "Salary", [
          Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
          Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
        ])
      ])

      # Asset accounts only
      Beancount.Queries.list_opens(prefix: "Assets")
      # => [%Beancount.Schemas.Open{account: "Assets:Bank"}, ...]

      # Transactions in January
      Beancount.Queries.find_transactions(
        payee: "Employer",
        from_date: ~D[2026-01-01],
        to_date: ~D[2026-01-31]
      )

      # Ledger composition
      Beancount.Queries.count_by_type()
      # => [opens: 2, transactions: 1, ...]
  """

  import Ecto.Query

  alias Beancount.{Repo, Schemas}

  @doc """
  List all open directives, optionally filtered by account prefix.

  Results are ordered by account name. Pass `:prefix` to restrict to accounts
  under a given root (matched as `prefix:%`).

  ## Examples

      # All opens
      Beancount.Queries.list_opens()
      # => [%Beancount.Schemas.Open{account: "Assets:Bank"}, ...]

      # Only asset accounts
      Beancount.Queries.list_opens(prefix: "Assets")
      # => [%Beancount.Schemas.Open{account: "Assets:Bank"}, %Beancount.Schemas.Open{account: "Assets:Cash"}]

  """
  @spec list_opens(keyword()) :: [Schemas.Open.t()]
  def list_opens(opts \\ []) do
    prefix = Keyword.get(opts, :prefix)

    query =
      from(o in Schemas.Open,
        order_by: o.account
      )

    query =
      if prefix do
        from(o in query, where: like(o.account, ^"#{prefix}:%"))
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  List all close directives, ordered by account name.

  ## Examples

      Beancount.Queries.list_closes()
      # => [%Beancount.Schemas.Close{account: "Assets:Bank", date: ~D[2026-12-31]}]

  """
  @spec list_closes() :: [Schemas.Close.t()]
  def list_closes do
    Repo.all(from(c in Schemas.Close, order_by: c.account))
  end

  @doc """
  Count transactions grouped by date, ordered by date.

  Returns a list of `{date, count}` tuples.

  ## Examples

      Beancount.Queries.count_transactions_by_date()
      # => [{~D[2026-01-15], 1}, {~D[2026-02-15], 3}]

  """
  @spec count_transactions_by_date() :: [{Date.t(), non_neg_integer()}]
  def count_transactions_by_date do
    Repo.all(
      from(t in Schemas.Transaction,
        group_by: t.date,
        order_by: t.date,
        select: {t.date, count(t.id)}
      )
    )
  end

  @doc """
  Find transactions matching the given criteria, ordered by date.

  Supported options (all optional, combined with `AND`):

    * `:payee` - exact payee match.
    * `:narration` - substring match on the narration via SQL `LIKE`. Case
      sensitivity is backend-dependent: the default SQLite backend is
      case-insensitive for ASCII only; other backends (e.g. the planned
      PostgreSQL storage) treat `LIKE` as case-sensitive.
    * `:from_date` - only transactions on or after this `Date`.
    * `:to_date` - only transactions on or before this `Date`.

  ## Examples

      # By payee
      Beancount.Queries.find_transactions(payee: "Employer")

      # Narration substring within a date range
      Beancount.Queries.find_transactions(narration: "coffee", from_date: ~D[2026-01-01], to_date: ~D[2026-01-31])

  """
  @spec find_transactions(keyword()) :: [Schemas.Transaction.t()]
  def find_transactions(opts \\ []) do
    payee = Keyword.get(opts, :payee)
    narration = Keyword.get(opts, :narration)
    from_date = Keyword.get(opts, :from_date)
    to_date = Keyword.get(opts, :to_date)

    query = from(t in Schemas.Transaction, order_by: t.date)

    query =
      if payee do
        from(t in query, where: t.payee == ^payee)
      else
        query
      end

    query =
      if narration do
        from(t in query, where: like(t.narration, ^"%#{narration}%"))
      else
        query
      end

    query =
      if from_date do
        from(t in query, where: t.date >= ^from_date)
      else
        query
      end

    query =
      if to_date do
        from(t in query, where: t.date <= ^to_date)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  List all price directives for a commodity, ordered by date.

  ## Examples

      Beancount.Queries.list_prices("AAPL")
      # => [%Beancount.Schemas.Price{commodity: "AAPL", date: ~D[2026-01-02]}]

  """
  @spec list_prices(String.t()) :: [Schemas.Price.t()]
  def list_prices(commodity) do
    Repo.all(
      from(p in Schemas.Price,
        where: p.commodity == ^commodity,
        order_by: p.date
      )
    )
  end

  @doc """
  List all balance assertions for an account, ordered by date.

  ## Examples

      Beancount.Queries.list_balances("Assets:Bank")
      # => [%Beancount.Schemas.Balance{account: "Assets:Bank", date: ~D[2026-01-31]}]

  """
  @spec list_balances(String.t()) :: [Schemas.Balance.t()]
  def list_balances(account) do
    Repo.all(
      from(b in Schemas.Balance,
        where: b.account == ^account,
        order_by: b.date
      )
    )
  end

  @doc """
  Count all stored directives grouped by type.

  Returns a keyword-style list of `{type, count}` tuples, one per directive
  table.

  Includes one entry for every directive table, so undated directives
  (includes, plugins, pushtags, poptags, queries) are represented too.

  ## Examples

      Beancount.Queries.count_by_type()
      # => [opens: 5, closes: 0, commodities: 3, transactions: 42, balances: 4,
      #     prices: 12, notes: 0, documents: 0, events: 0, customs: 1, pads: 0,
      #     includes: 0, options: 2, plugins: 0, push_tags: 0, pop_tags: 0,
      #     queries: 0]

  """
  @spec count_by_type() :: [{atom(), non_neg_integer()}]
  def count_by_type do
    [
      {:opens, Repo.aggregate(Schemas.Open, :count)},
      {:closes, Repo.aggregate(Schemas.Close, :count)},
      {:commodities, Repo.aggregate(Schemas.Commodity, :count)},
      {:transactions, Repo.aggregate(Schemas.Transaction, :count)},
      {:balances, Repo.aggregate(Schemas.Balance, :count)},
      {:prices, Repo.aggregate(Schemas.Price, :count)},
      {:notes, Repo.aggregate(Schemas.Note, :count)},
      {:documents, Repo.aggregate(Schemas.Document, :count)},
      {:events, Repo.aggregate(Schemas.Event, :count)},
      {:customs, Repo.aggregate(Schemas.Custom, :count)},
      {:pads, Repo.aggregate(Schemas.Pad, :count)},
      {:includes, Repo.aggregate(Schemas.Include, :count)},
      {:options, Repo.aggregate(Schemas.Option, :count)},
      {:plugins, Repo.aggregate(Schemas.Plugin, :count)},
      {:push_tags, Repo.aggregate(Schemas.PushTag, :count)},
      {:pop_tags, Repo.aggregate(Schemas.PopTag, :count)},
      {:queries, Repo.aggregate(Schemas.Query, :count)}
    ]
  end
end
