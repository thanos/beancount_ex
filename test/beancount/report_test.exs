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

  test "balance_sheet/1, income_statement/1, holdings/1 return results" do
    # These dispatch through FakeBeanQuery which returns a fixed CSV.
    # Verify that each report returns a result (column shapes depend on the
    # engine; the native engine is tested in elixir_test.exs and reports_test.exs).
    assert {:ok, %Result{}} = Beancount.Report.balance_sheet(@ledger)
    assert {:ok, %Result{}} = Beancount.Report.income_statement(@ledger)
    assert {:ok, %Result{}} = Beancount.Report.holdings(@ledger)
  end

  test "journal/2 quotes the account into the query" do
    assert {:ok, %Result{}} = Beancount.Report.journal(@ledger, "Assets:Bank")
  end

  test "journal/2 escapes backslashes in account names for BQL" do
    capture_path = Path.join(System.tmp_dir!(), "bql_#{System.unique_integer([:positive])}.txt")
    script = recording_bean_query!(capture_path)
    original = Application.get_env(:beancount_ex, :bean_query_path)
    Application.put_env(:beancount_ex, :bean_query_path, script)
    on_exit(fn -> Application.put_env(:beancount_ex, :bean_query_path, original) end)

    account = ~S(Assets\b"Bank)
    assert {:ok, %Result{}} = Beancount.Report.journal(@ledger, account)

    bql = File.read!(capture_path)
    assert bql =~ "WHERE account = #{Beancount.Renderer.quote_string(account)}"
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

  defp recording_bean_query!(capture_path) do
    dir = Path.join(System.tmp_dir!(), "record_bq_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    script = Path.join(dir, "bean-query")

    File.write!(script, """
    #!/bin/sh
    for arg in "$@"; do bql="$arg"; done
    printf '%s' "$bql" > "#{capture_path}"
    printf 'account,balance\\r\\n'
    exit 0
    """)

    File.chmod!(script, 0o755)
    script
  end
end
