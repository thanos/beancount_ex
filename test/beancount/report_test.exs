defmodule Beancount.ReportTest do
  use ExUnit.Case, async: false

  alias Beancount.Query.Result

  @ledger [
    Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
    Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
    Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
      Beancount.posting("Assets:Bank", Decimal.new("5000"), "USD"),
      Beancount.posting("Income:Salary", Decimal.new("-5000"), "USD")
    ])
  ]

  setup do
    Beancount.FakeBeanQuery.install!()
    :ok
  end

  test "balances/1 accepts a directive list" do
    assert {:ok, %Result{columns: ["account", "balance"]}} = Beancount.Report.balances(@ledger)
  end

  test "balances/1 accepts raw text" do
    assert {:ok, %Result{}} = Beancount.Report.balances("2026-01-01 open Assets:Bank USD\n")
  end

  test "balance_sheet/1, income_statement/1, holdings/1 dispatch successfully" do
    assert {:ok, %Result{}} = Beancount.Report.balance_sheet(@ledger)
    assert {:ok, %Result{}} = Beancount.Report.income_statement(@ledger)
    assert {:ok, %Result{}} = Beancount.Report.holdings(@ledger)
  end

  test "journal/2 quotes the account into the query" do
    assert {:ok, %Result{}} = Beancount.Report.journal(@ledger, "Assets:Bank")
  end

  test "public API delegations work" do
    assert {:ok, %Result{}} = Beancount.balances(@ledger)
    assert {:ok, %Result{}} = Beancount.balance_sheet(@ledger)
    assert {:ok, %Result{}} = Beancount.income_statement(@ledger)
    assert {:ok, %Result{}} = Beancount.holdings(@ledger)
    assert {:ok, %Result{}} = Beancount.journal(@ledger, "Assets:Bank")
  end

  test "query/2 and query_file/2 public API" do
    assert {:ok, %Result{}} = Beancount.query(@ledger, "SELECT account")

    path = Path.join(System.tmp_dir!(), "report_#{System.unique_integer([:positive])}.bean")
    File.write!(path, "2026-01-01 open Assets:Bank USD\n")
    on_exit(fn -> File.rm(path) end)
    assert {:ok, %Result{}} = Beancount.query_file(path, "SELECT account")
  end
end
