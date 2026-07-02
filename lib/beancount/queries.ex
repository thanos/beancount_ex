defmodule Beancount.Queries do
  @moduledoc """
  Ecto.Query-based queries against stored Beancount directives.

  These queries run directly against the database tables — no booking engine
  required. Use for listing, filtering, and simple aggregations of raw
  directives. For balance reports that need inventory booking, use
  `Beancount.Report` (which dispatches through the configured engine).

  ## Examples

      # List all open directives for asset accounts
      Beancount.Queries.list_opens(prefix: "Assets")

      # Count transactions by date
      Beancount.Queries.count_transactions_by_date()

      # Find transactions with a specific payee
      Beancount.Queries.find_transactions(payee: "Employer")
  """

  import Ecto.Query

  alias Beancount.{Repo, Schemas}

  @doc "List all open directives, optionally filtered by account prefix."
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

  @doc "List all close directives."
  @spec list_closes() :: [Schemas.Close.t()]
  def list_closes do
    Repo.all(from(c in Schemas.Close, order_by: c.account))
  end

  @doc "Count transactions, optionally grouped by date."
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

  @doc "Find transactions matching the given criteria."
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
        from(t in query, where: ilike(t.narration, ^"%#{narration}%"))
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

  @doc "List all price directives for a commodity."
  @spec list_prices(String.t()) :: [Schemas.Price.t()]
  def list_prices(commodity) do
    Repo.all(
      from(p in Schemas.Price,
        where: p.commodity == ^commodity,
        order_by: p.date
      )
    )
  end

  @doc "List all balance assertions for an account."
  @spec list_balances(String.t()) :: [Schemas.Balance.t()]
  def list_balances(account) do
    Repo.all(
      from(b in Schemas.Balance,
        where: b.account == ^account,
        order_by: b.date
      )
    )
  end

  @doc "Count all directives by type."
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
      {:options, Repo.aggregate(Schemas.Option, :count)}
    ]
  end
end
