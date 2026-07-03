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

  @cost_ledger [
    Beancount.open(~D[2026-01-01], "Assets:Stocks", ["AAPL"], booking: "STRICT"),
    Beancount.open(~D[2026-01-01], "Assets:Cash", ["USD"]),
    Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
    Beancount.transaction(~D[2026-01-02], "*", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        cost: %Beancount.CostSpec{per_amount: Decimal.new("150"), per_currency: "USD"}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-1500"), "USD")
    ])
  ]

  test "balances/1 formats positions held at cost" do
    assert {:ok, %Beancount.Query.Result{rows: rows}} = Reports.balances(@cost_ledger)

    stock_row = Enum.find(rows, fn [account | _] -> account == "Assets:Stocks" end)
    assert [_, position] = stock_row
    assert position =~ "10 AAPL"
    assert position =~ "{ 150 USD}"
  end

  test "holdings/1 returns an empty row for an opened asset account with no net position" do
    ledger = [
      Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
      Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
      Beancount.transaction(~D[2026-01-10], "*", nil, "In", [
        Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
        Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
      ]),
      Beancount.transaction(~D[2026-01-20], "*", nil, "Out", [
        Beancount.posting("Assets:Bank", Decimal.new("-100"), "USD"),
        Beancount.posting("Income:Salary", Decimal.new("100"), "USD")
      ])
    ]

    assert {:ok, %Beancount.Query.Result{rows: rows}} = Reports.holdings(ledger)
    assert ["Assets:Bank", "", ""] in rows
  end

  test "run/2 journal query with an unquoted account fails closed as unsupported BQL" do
    bql = "SELECT date, flag, payee, narration, position, balance WHERE account = Assets:Bank"

    assert {:error,
            %Beancount.Result{status: :error, normalized: %{errors: [%{message: message}]}}} =
             Reports.run(@ledger, bql)

    assert message =~ "unsupported native BQL"
  end

  test "journal/2 tolerates postings without a resolved amount or currency" do
    txn = %Beancount.Directives.Transaction{
      date: ~D[2026-03-01],
      flag: "*",
      payee: nil,
      narration: "Elided",
      postings: [
        %Beancount.Directives.Posting{account: "Assets:Bank", amount: nil, currency: nil},
        %Beancount.Directives.Posting{account: "Income:Salary", amount: nil, currency: nil}
      ],
      tags: [],
      links: [],
      metadata: %{}
    }

    assert {:ok, %Beancount.Query.Result{rows: rows}} = Reports.journal([txn], "Assets:Bank")
    assert [["2026-03-01", "*", "", "Elided", "", balance]] = rows
    assert balance == "0"
  end
end
