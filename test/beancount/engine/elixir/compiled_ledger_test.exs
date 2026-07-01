defmodule Beancount.Engine.Elixir.CompiledLedgerTest do
  use ExUnit.Case, async: true

  alias Beancount.Engine.Elixir.CompiledLedger

  @ledger [
    Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
    Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
    Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
    Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
      Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
      Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
    ])
  ]

  test "compile/1 and query/2 evaluate BQL without re-processing" do
    compiled = CompiledLedger.compile(@ledger)
    on_exit(fn -> CompiledLedger.close(compiled) end)

    {:ok, query} =
      Beancount.BQL.parse(
        "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account"
      )

    assert {:ok, %Beancount.Query.Result{columns: ["account", "balance"], rows: rows}} =
             CompiledLedger.query(compiled, query)

    assert Enum.any?(rows, fn [account, _] -> account == "Assets:Bank" end)
  end

  test "close/1 destroys ETS tables when indexing is enabled" do
    directives =
      for index <- 1..1_001,
          do: Beancount.open(~D[2026-01-01], "Assets:Tmp#{index}", ["USD"])

    compiled = CompiledLedger.compile(directives)
    assert compiled.index != nil
    assert :ok = CompiledLedger.close(compiled)
  end
end
