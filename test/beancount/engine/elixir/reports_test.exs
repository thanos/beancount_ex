defmodule Beancount.Engine.Elixir.ReportsTest do
  use ExUnit.Case, async: true

  alias Beancount.Engine.Elixir.Reports

  @ledger [
    Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
    Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
    Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
    Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
      Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
      Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
    ])
  ]

  test "balances/1 returns account balances" do
    assert {:ok, %Beancount.Query.Result{columns: ["account", "balance"], rows: rows}} =
             Reports.balances(@ledger)

    assert ["Assets:Bank", "100 USD"] in rows
  end

  test "balance_sheet/1 filters assets, liabilities, and equity" do
    assert {:ok, %Beancount.Query.Result{rows: rows}} = Reports.balance_sheet(@ledger)
    assert Enum.all?(rows, fn [account, _] -> account =~ ~r/^(Assets|Liabilities|Equity)/ end)
  end

  test "income_statement/1 filters income and expenses" do
    assert {:ok, %Beancount.Query.Result{rows: rows}} = Reports.income_statement(@ledger)
    assert ["Income:Salary", "-100 USD"] in rows
  end

  test "holdings/1 returns units and cost for asset accounts" do
    assert {:ok, %Beancount.Query.Result{columns: columns, rows: rows}} =
             Reports.holdings(@ledger)

    assert columns == ["account", "units", "cost"]
    assert ["Assets:Bank", "100 USD", "100 USD"] in rows
  end

  test "journal/1 escapes quotes in account names" do
    ledger =
      @ledger ++
        [
          Beancount.open(~D[2026-01-01], "Assets:Quoted", ["USD"]),
          Beancount.transaction(~D[2026-02-01], "*", nil, "Move", [
            Beancount.posting("Assets:Quoted", Decimal.new("5"), "USD"),
            Beancount.posting("Equity:Opening", Decimal.new("-5"), "USD")
          ])
        ]

    assert {:ok, %Beancount.Query.Result{rows: rows}} =
             Reports.journal(ledger, "Assets:Quoted")

    assert Enum.any?(rows, fn row -> Enum.at(row, 0) == "2026-02-01" end)
  end

  test "run/2 returns unsupported BQL error for invalid syntax" do
    assert {:error, %Beancount.Result{stdout: stdout}} =
             Reports.run(@ledger, "SELECT not_supported()")

    assert stdout =~ "unsupported native BQL"
  end

  test "run/2 returns unsupported BQL error for unsupported query shapes" do
    assert {:error, %Beancount.Result{stdout: stdout}} =
             Reports.run(@ledger, "SELECT count(*)")

    assert stdout =~ "unsupported native BQL"
  end
end
