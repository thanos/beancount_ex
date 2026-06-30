defmodule Beancount.Report do
  @moduledoc """
  Higher-level reporting API built on top of `Beancount.query_text/2`.

  Each function generates a canned [BQL](https://beancount.github.io/docs/beancount_query_language.html)
  query and runs it through the configured engine, returning a neutral
  `Beancount.Query.Result`. Reports therefore work against any engine that
  implements `c:Beancount.Engine.query/2`.

  A `ledger` argument may be either a list of directives (which is rendered
  first) or raw `.bean` text.
  """

  @type ledger :: [Beancount.directive()] | binary()
  @type result :: {:ok, Beancount.Query.Result.t()} | {:error, Beancount.Result.t()}

  @doc """
  Balances for every account.

  BQL: `SELECT account, sum(position) AS balance GROUP BY account ORDER BY account`.
  """
  @spec balances(ledger()) :: result()
  def balances(ledger) do
    run(ledger, "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account")
  end

  @doc """
  Balance sheet: balances of Assets, Liabilities and Equity accounts.
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
  """
  @spec journal(ledger(), String.t()) :: result()
  def journal(ledger, account) when is_binary(account) do
    run(ledger, """
    SELECT date, flag, payee, narration, position, balance \
    WHERE account = #{quote_bql(account)} ORDER BY date\
    """)
  end

  defp run(ledger, bql) when is_list(ledger), do: ledger |> Beancount.render() |> run(bql)
  defp run(ledger, bql) when is_binary(ledger), do: Beancount.query_text(ledger, bql)

  alias Beancount.Renderer

  defp quote_bql(value) do
    Renderer.quote_string(value)
  end
end
