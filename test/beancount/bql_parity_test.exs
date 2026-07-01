defmodule Beancount.BQLParityTest do
  use ExUnit.Case, async: false

  alias Beancount.Engine.CLI
  alias Beancount.Engine.Elixir, as: NativeEngine

  @queries [
    "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account",
    "SELECT account, sum(position) AS balance WHERE account ~ \"^(Assets|Liabilities|Equity)\" GROUP BY account ORDER BY account",
    "SELECT account, sum(position) AS balance WHERE account ~ \"^(Income|Expenses)\" GROUP BY account ORDER BY account",
    "SELECT account, units(sum(position)) AS units, cost(sum(position)) AS cost WHERE account ~ \"^Assets\" GROUP BY account ORDER BY account",
    "SELECT date, flag, payee, narration, position, balance WHERE account = \"Assets:Bank\" ORDER BY date"
  ]

  setup do
    ledger = """
    2026-01-01 open Assets:Bank USD
    2026-01-01 open Income:Salary USD
    2026-01-01 open Equity:Opening USD

    2026-01-31 * "Employer" "Salary"
      Assets:Bank     100 USD
      Income:Salary  -100 USD
    """

    %{ledger: ledger}
  end

  @tag :beancount
  test "native BQL matches bean-query for canned reports", %{ledger: ledger} do
    for bql <- @queries do
      {:ok, oracle} = CLI.query(ledger, bql)
      {:ok, native} = NativeEngine.query(ledger, bql)

      assert normalize(oracle) == normalize(native), "mismatch for #{bql}"
    end
  end

  defp normalize(%Beancount.Query.Result{rows: rows}) do
    rows
    |> Enum.map(fn row -> Enum.map(row, &String.trim/1) end)
    |> Enum.sort()
  end
end
