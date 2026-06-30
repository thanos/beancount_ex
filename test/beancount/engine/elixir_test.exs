defmodule Beancount.Engine.ElixirTest do
  use ExUnit.Case, async: true

  alias Beancount.Engine.Elixir, as: NativeEngine

  @ledger """
  2026-01-01 open Assets:Bank USD
  2026-01-01 open Income:Salary USD
  2026-01-01 open Expenses:Food USD
  2026-01-01 open Liabilities:Card USD
  2026-01-01 open Equity:Opening USD

  2026-01-31 * "Employer" "Salary"
    Assets:Bank     5000 USD
    Income:Salary  -5000 USD

  2026-02-01 * "Store" "Purchase"
    Expenses:Food    50 USD
    Liabilities:Card -50 USD
  """

  test "check/1 accepts a balanced ledger" do
    assert {:ok, %Beancount.Result{status: :ok}} = NativeEngine.check(@ledger)
  end

  test "check_file/1 reads and validates a ledger file" do
    path =
      Path.join(System.tmp_dir!(), "elixir_engine_#{System.unique_integer([:positive])}.bean")

    File.write!(path, @ledger)
    on_exit(fn -> File.rm(path) end)

    assert {:ok, %Beancount.Result{status: :ok}} = NativeEngine.check_file(path)
  end

  test "check_file/1 raises when the file is missing" do
    assert_raise File.Error, fn ->
      NativeEngine.check_file("/tmp/does-not-exist-#{System.unique_integer([:positive])}.bean")
    end
  end

  test "check/1 returns parse errors from invalid text" do
    assert {:error, %Beancount.Result{normalized: %{errors: [error | _]}}} =
             NativeEngine.check("2026-01-01 open")

    assert error.message =~ "unknown"
  end

  test "check/1 rejects an unbalanced transaction" do
    text = """
    2026-01-01 open Assets:Bank USD
    2026-01-01 open Income:Salary USD

    2026-01-31 * "Employer" "Salary"
      Assets:Bank     5000 USD
      Income:Salary  -4000 USD
    """

    assert {:error, %Beancount.Result{status: :error, normalized: %{errors: errors}}} =
             NativeEngine.check(text)

    assert Enum.any?(errors, &String.contains?(&1.message, "balance"))
  end

  test "check/1 rejects duplicate opens, closes, and closed accounts" do
    assert {:error, %Beancount.Result{normalized: %{errors: errors}}} =
             NativeEngine.check("""
             2026-01-01 open Assets:Bank USD
             2026-01-02 open Assets:Bank USD
             """)

    assert Enum.any?(errors, &String.contains?(&1.message, "Duplicate open"))

    assert {:error, %Beancount.Result{normalized: %{errors: errors}}} =
             NativeEngine.check("""
             2026-01-01 close Assets:Bank
             """)

    assert Enum.any?(errors, &String.contains?(&1.message, "Unopened"))

    text = """
    2026-01-01 open Assets:Bank USD
    2026-01-02 close Assets:Bank
    2026-01-03 close Assets:Bank
    """

    assert {:error, %Beancount.Result{normalized: %{errors: errors}}} = NativeEngine.check(text)
    assert Enum.any?(errors, &String.contains?(&1.message, "Duplicate close"))

    text = """
    2026-01-01 open Assets:Bank USD
    2026-01-01 open Equity:Opening USD
    2026-01-02 close Assets:Bank

    2026-01-03 * "X" "After close"
      Assets:Bank  1 USD
      Equity:Opening  -1 USD
    """

    assert {:error, %Beancount.Result{normalized: %{errors: errors}}} = NativeEngine.check(text)
    assert Enum.any?(errors, &String.contains?(&1.message, "after close"))
  end

  test "check/1 allows transactions before an account is closed" do
    text = """
    2026-01-01 open Assets:Bank USD
    2026-01-01 open Equity:Opening USD

    2026-01-02 * "X" "Before close"
      Assets:Bank       1 USD
      Equity:Opening   -1 USD

    2026-01-03 close Assets:Bank
    """

    assert {:ok, %Beancount.Result{status: :ok}} = NativeEngine.check(text)
  end

  test "check/1 accepts cost-basis postings" do
    text = """
    2026-01-01 open Assets:Stocks AAPL
    2026-01-01 open Assets:Cash USD

    2026-01-02 * "Buy"
      Assets:Stocks  10 AAPL {150 USD}
      Assets:Cash  -1500 USD
    """

    assert {:ok, %Beancount.Result{status: :ok}} = NativeEngine.check(text)
  end

  test "check/1 rejects accounts used before open" do
    text = """
    2026-01-31 * "Employer" "Salary"
      Assets:Bank     5000 USD
      Income:Salary  -5000 USD
    """

    assert {:error, %Beancount.Result{status: :error}} = NativeEngine.check(text)
  end

  test "query/2 runs canned reports" do
    balances_bql = "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account"

    assert {:ok, %Beancount.Query.Result{columns: ["account", "balance"], rows: rows}} =
             NativeEngine.query(@ledger, balances_bql)

    accounts = Enum.map(rows, &List.first/1)
    assert "Assets:Bank" in accounts
    assert "Income:Salary" in accounts

    sheet_bql =
      "SELECT account, sum(position) AS balance WHERE account ~ \"^(Assets|Liabilities|Equity)\" GROUP BY account ORDER BY account"

    assert {:ok, %Beancount.Query.Result{rows: sheet_rows}} =
             NativeEngine.query(@ledger, sheet_bql)

    assert Enum.all?(sheet_rows, fn [account | _] ->
             account =~ ~r/^(Assets|Liabilities|Equity):/
           end)

    income_bql =
      "SELECT account, sum(position) AS balance WHERE account ~ \"^(Income|Expenses)\" GROUP BY account ORDER BY account"

    assert {:ok, %Beancount.Query.Result{rows: income_rows}} =
             NativeEngine.query(@ledger, income_bql)

    assert Enum.any?(income_rows, fn [account | _] -> String.starts_with?(account, "Income:") end)

    holdings_bql =
      "SELECT account, units(sum(position)) AS units, cost(sum(position)) AS cost WHERE account ~ \"^Assets\" GROUP BY account ORDER BY account"

    assert {:ok,
            %Beancount.Query.Result{columns: ["account", "units", "cost"], rows: holdings_rows}} =
             NativeEngine.query(@ledger, holdings_bql)

    assert Enum.any?(holdings_rows, fn [account | _] -> account == "Assets:Bank" end)
  end

  test "query/2 runs journal queries for an account" do
    bql =
      ~s(SELECT date, flag, payee, narration, position, balance WHERE account = "Assets:Bank" ORDER BY date)

    assert {:ok, %Beancount.Query.Result{columns: columns, rows: rows}} =
             NativeEngine.query(@ledger, bql)

    assert columns == ["date", "flag", "payee", "narration", "position", "balance"]
    assert ["2026-01-31", "*", "Employer", "Salary", "5000 USD", "5000 USD"] in rows
  end

  test "query/2 holdings report separates units and cost" do
    text = """
    2026-01-01 open Assets:Stocks AAPL
    2026-01-01 open Assets:Cash USD

    2026-01-02 * "Buy"
      Assets:Stocks  10 AAPL {150 USD}
      Assets:Cash  -1500 USD
    """

    holdings_bql =
      "SELECT account, units(sum(position)) AS units, cost(sum(position)) AS cost WHERE account ~ \"^Assets\" GROUP BY account ORDER BY account"

    assert {:ok, %Beancount.Query.Result{rows: rows}} = NativeEngine.query(text, holdings_bql)

    assert ["Assets:Stocks", "10 AAPL", "1500 USD"] in rows
  end

  test "query/2 returns parse and unsupported BQL errors" do
    assert {:error, %Beancount.Result{status: :error}} =
             NativeEngine.query("2026-01-01 open", balances_bql())

    assert {:error, %Beancount.Result{stdout: stdout}} =
             NativeEngine.query(@ledger, "SELECT not_supported")

    assert stdout =~ "unsupported native BQL"
  end

  test "render/1 delegates to the renderer" do
    directives = Beancount.parse!(@ledger)
    assert NativeEngine.render(directives) == Beancount.render(directives)
  end

  defp balances_bql do
    "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account"
  end
end
