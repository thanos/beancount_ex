defmodule Beancount.Engine.ElixirTest do
  use ExUnit.Case, async: true

  alias Beancount.Engine.Elixir, as: NativeEngine

  @ledger """
  2026-01-01 open Assets:Bank USD
  2026-01-01 open Income:Salary USD

  2026-01-31 * "Employer" "Salary"
    Assets:Bank     5000 USD
    Income:Salary  -5000 USD
  """

  test "check/1 accepts a balanced ledger" do
    assert {:ok, %Beancount.Result{status: :ok}} = NativeEngine.check(@ledger)
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

  test "check/1 rejects accounts used before open" do
    text = """
    2026-01-31 * "Employer" "Salary"
      Assets:Bank     5000 USD
      Income:Salary  -5000 USD
    """

    assert {:error, %Beancount.Result{status: :error}} = NativeEngine.check(text)
  end

  test "query/2 runs canned balances report" do
    assert {:ok, %Beancount.Query.Result{columns: columns, rows: rows}} =
             NativeEngine.query(
               @ledger,
               "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account"
             )

    assert columns == ["account", "balance"]
    accounts = Enum.map(rows, &List.first/1)
    assert "Assets:Bank" in accounts
    assert "Income:Salary" in accounts
  end

  test "query/2 returns an error for unsupported BQL" do
    assert {:error, %Beancount.Result{status: :error}} =
             NativeEngine.query(@ledger, "SELECT not_supported")
  end

  test "render/1 delegates to the renderer" do
    directives = Beancount.parse!(@ledger)
    assert NativeEngine.render(directives) == Beancount.render(directives)
  end
end
