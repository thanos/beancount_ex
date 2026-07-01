defmodule Beancount.Report do
  @moduledoc """
  Higher-level reporting API built on top of `Beancount.query_text/2`.

  Each function generates a canned [BQL](https://beancount.github.io/docs/beancount_query_language.html)
  query and runs it through the configured engine, returning a neutral
  `Beancount.Query.Result`. Reports therefore work against any engine that
  implements `c:Beancount.Engine.query/2`.

  A `ledger` argument may be either a list of directives (which is rendered
  first) or raw `.bean` text.

  Examples below use `Beancount.Engine.Elixir` so they run without `bean-query`.
  Configure `config :beancount_ex, engine: Beancount.Engine.Elixir` to use these
  reports through `Beancount.balances/1` and friends.
  """

  @type ledger :: [Beancount.directive()] | binary()
  @type result :: {:ok, Beancount.Query.Result.t()} | {:error, Beancount.Result.t()}

  @sample_ledger [
    Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
    Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
    Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
    Beancount.transaction(~D[2026-01-31], "*", nil, "Salary", [
      Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
      Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
    ])
  ]

  @doc """
  Balances for every account.

  BQL: `SELECT account, sum(position) AS balance GROUP BY account ORDER BY account`.

  ## Examples

      iex> Application.put_env(:beancount_ex, :engine, Beancount.Engine.Elixir)
      iex> {:ok, result} = Beancount.Report.balances(Beancount.Report.sample_ledger())
      iex> result.columns
      ["account", "balance"]

  """
  @spec balances(ledger()) :: result()
  def balances(ledger) do
    run(ledger, "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account")
  end

  @doc """
  Balance sheet: balances of Assets, Liabilities and Equity accounts.

  ## Examples

      iex> Application.put_env(:beancount_ex, :engine, Beancount.Engine.Elixir)
      iex> {:ok, %Beancount.Query.Result{}} = Beancount.Report.balance_sheet(Beancount.Report.sample_ledger())

  """
  @spec balance_sheet(ledger()) :: result()
  def balance_sheet(ledger) do
    run(ledger, """
    SELECT account, sum(position) AS balance \
    WHERE account ~ "^(Assets|Liabilities|Equity)" \
    GROUP BY account ORDER BY account\
    """)
  end

  @doc """
  Income statement: balances of Income and Expenses accounts.

  ## Examples

      iex> Application.put_env(:beancount_ex, :engine, Beancount.Engine.Elixir)
      iex> {:ok, %Beancount.Query.Result{}} = Beancount.Report.income_statement(Beancount.Report.sample_ledger())

  """
  @spec income_statement(ledger()) :: result()
  def income_statement(ledger) do
    run(ledger, """
    SELECT account, sum(position) AS balance \
    WHERE account ~ "^(Income|Expenses)" \
    GROUP BY account ORDER BY account\
    """)
  end

  @doc """
  Holdings: unit and cost positions held in Asset accounts.

  ## Examples

      ledger = [
        Beancount.open(~D[2026-01-01], "Assets:Stocks", ["AAPL"], booking: "FIFO"),
        Beancount.open(~D[2026-01-01], "Assets:Cash", ["USD"]),
        Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
        Beancount.transaction(~D[2026-01-02], "*", nil, "Buy", [
          Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
            cost: %{amount: Decimal.new("150"), currency: "USD"}
          ),
          Beancount.posting("Assets:Cash", Decimal.new("-1500"), "USD")
        ])
      ]

      Application.put_env(:beancount_ex, :engine, Beancount.Engine.Elixir)
      {:ok, %Beancount.Query.Result{columns: cols}} = Beancount.Report.holdings(ledger)
      cols
      # => ["account", "units", "cost"]

  """
  @spec holdings(ledger()) :: result()
  def holdings(ledger) do
    run(ledger, """
    SELECT account, units(sum(position)) AS units, cost(sum(position)) AS cost \
    WHERE account ~ "^Assets" \
    GROUP BY account ORDER BY account\
    """)
  end

  @doc """
  Journal of postings for a single `account`, ordered by date.

  ## Examples

      iex> Application.put_env(:beancount_ex, :engine, Beancount.Engine.Elixir)
      iex> {:ok, %Beancount.Query.Result{columns: cols}} =
      ...>   Beancount.Report.journal(Beancount.Report.sample_ledger(), "Assets:Bank")
      iex> "date" in cols
      true

  """
  @spec journal(ledger(), String.t()) :: result()
  def journal(ledger, account) when is_binary(account) do
    run(ledger, """
    SELECT date, flag, payee, narration, position, balance \
    WHERE account = #{quote_bql(account)} ORDER BY date\
    """)
  end

  @doc false
  @spec sample_ledger() :: [Beancount.directive()]
  def sample_ledger, do: @sample_ledger

  defp run(ledger, bql) when is_list(ledger), do: ledger |> Beancount.render() |> run(bql)
  defp run(ledger, bql) when is_binary(ledger), do: Beancount.query_text(ledger, bql)

  alias Beancount.Renderer

  defp quote_bql(value) do
    Renderer.quote_string(value)
  end
end
