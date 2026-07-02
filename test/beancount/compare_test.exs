defmodule Beancount.CompareTest do
  use ExUnit.Case, async: false

  setup do
    Beancount.FakeEngine.ensure!()
    :ok
  end

  @ledger [
    Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
    Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
    Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
      Beancount.posting("Assets:Bank", Decimal.new("5000"), "USD"),
      Beancount.posting("Income:Salary", Decimal.new("-5000"), "USD")
    ])
  ]

  test "compare/3 reports equivalent engines as equivalent" do
    assert {:ok, :equivalent} =
             Beancount.Compare.compare(
               Beancount.Engine.Elixir,
               Beancount.Engine.Elixir,
               @ledger
             )
  end

  test "compare/3 accepts binary ledger text" do
    assert {:ok, :equivalent} =
             Beancount.Compare.compare(
               Beancount.Engine.Elixir,
               Beancount.Engine.Elixir,
               Beancount.render(@ledger)
             )
  end

  test "compare/3 reports equivalent engines for pad ledgers" do
    assert {:ok, :equivalent} =
             Beancount.Compare.compare(
               Beancount.Engine.Elixir,
               Beancount.Engine.Elixir,
               """
               2026-01-01 open Assets:Cash USD
               2026-01-01 open Equity:Opening
               2026-01-02 pad Assets:Cash Equity:Opening
               2026-01-03 balance Assets:Cash  5 USD
               """
             )
  end

  test "compare/3 returns a structured diff on query mismatch" do
    assert {:error, %Beancount.Property.Diff{callback: :query, message: message}} =
             Beancount.Compare.compare(
               Beancount.FakeEngine,
               Beancount.Engine.Elixir,
               @ledger
             )

    assert message =~ "query"
  end

  test "compare/3 returns a structured diff on check mismatch" do
    broken = """
    2026-01-01 open Assets:Bank USD
    2026-01-01 open Income:Salary USD

    2026-01-31 * "Employer" "Salary"
      Assets:Bank     5000 USD
      Income:Salary  -4000 USD
    """

    assert {:error, %Beancount.Property.Diff{callback: :check, message: message}} =
             Beancount.Compare.compare(
               Beancount.FakeEngine,
               Beancount.Engine.Elixir,
               broken
             )

    assert message =~ "check"
  end

  test "compare/3 normalizes equivalent query rows with different lot formatting" do
    ledger = Beancount.render(@ledger)

    assert {:ok, :equivalent} =
             Beancount.Compare.compare(
               Beancount.CompareTest.QueryFormatA,
               Beancount.CompareTest.QueryFormatB,
               ledger
             )
  end

  test "compare/3 normalizes merged cost lots and zero positions" do
    stocks_ledger = [
      Beancount.open(~D[2026-01-01], "Assets:Stocks", ["AAPL"]),
      Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"])
    ]

    assert {:ok, :equivalent} =
             Beancount.Compare.compare(
               Beancount.CompareTest.PositionLotsA,
               Beancount.CompareTest.PositionLotsB,
               stocks_ledger
             )
  end

  test "compare/3 ignores bean-check context lines in other_errors" do
    ledger = Beancount.render(@ledger)

    assert {:ok, :equivalent} =
             Beancount.Compare.compare(
               Beancount.CompareTest.CLIContextOracle,
               Beancount.CompareTest.CLIContextNative,
               ledger
             )
  end

  test "compare/3 treats uncategorized errors on one side as non-equivalent" do
    ledger = Beancount.render(@ledger)

    assert {:error, %Beancount.Property.Diff{callback: :check}} =
             Beancount.Compare.compare(
               Beancount.CompareTest.OtherErrorA,
               Beancount.CompareTest.CLIContextNative,
               ledger
             )
  end

  test "compare/3 rejects different uncategorized errors" do
    ledger = Beancount.render(@ledger)

    assert {:error, %Beancount.Property.Diff{callback: :check}} =
             Beancount.Compare.compare(
               Beancount.CompareTest.OtherErrorA,
               Beancount.CompareTest.OtherErrorB,
               ledger
             )
  end

  test "compare/3 treats booking insufficient errors as equivalent" do
    assert {:ok, :equivalent} =
             Beancount.Compare.compare(
               Beancount.CompareTest.BookingInsufficientCLI,
               Beancount.CompareTest.BookingInsufficientNative,
               Beancount.Golden.render(
                 Path.join(Beancount.Golden.root(), "booking_spec_too_small")
               )
             )
  end

  test "compare/3 returns query diff when an engine fails a canned query" do
    assert {:error, %Beancount.Property.Diff{callback: :query, message: "query failed"}} =
             Beancount.Compare.compare(
               Beancount.BrokenQueryEngine,
               Beancount.Engine.Elixir,
               @ledger
             )
  end

  test "compare/3 normalizes unique non-position cells" do
    stocks_ledger = [Beancount.open(~D[2026-01-01], "Assets:Stocks", ["AAPL"])]

    assert {:ok, :equivalent} =
             Beancount.Compare.compare(
               Beancount.CompareTest.UniqueCellA,
               Beancount.CompareTest.UniqueCellB,
               stocks_ledger
             )
  end

  test "compare/3 reports query failures from an engine" do
    assert {:error, %Beancount.Property.Diff{callback: :query, message: "query failed"}} =
             Beancount.Compare.compare(
               Beancount.BrokenQueryEngine,
               Beancount.Engine.Elixir,
               @ledger
             )

    assert {:error, %Beancount.Property.Diff{callback: :query, message: "query failed"}} =
             Beancount.Compare.compare(
               Beancount.Engine.Elixir,
               Beancount.BrokenQueryEngine,
               @ledger
             )
  end

  test "BrokenQueryEngine implements check and check_file" do
    assert Beancount.BrokenQueryEngine.render([]) == ""

    assert {:ok, %Beancount.Result{status: :ok}} =
             Beancount.BrokenQueryEngine.check(Beancount.render(@ledger))

    path = Path.join(System.tmp_dir!(), "compare_#{System.unique_integer([:positive])}.bean")
    File.write!(path, Beancount.render(@ledger))
    on_exit(fn -> File.rm(path) end)

    assert {:ok, %Beancount.Result{status: :ok}} = Beancount.BrokenQueryEngine.check_file(path)

    assert {:error, %Beancount.Result{status: :error}} =
             Beancount.BrokenQueryEngine.query("ledger", "SELECT account")
  end

  describe "position cell normalization" do
    # These test the private normalize_position_cell/1 indirectly via
    # compare/3 with stub engines that produce specific query results.

    test "plain amount normalizes decimal scale" do
      # 5000.00 USD and 5000 USD should be equivalent
      assert {:ok, :equivalent} =
               Beancount.Compare.compare(
                 Beancount.CompareTest.PlainAmountA,
                 Beancount.CompareTest.PlainAmountB,
                 Beancount.render(@ledger)
               )
    end

    test "zero-balance cells are dropped" do
      assert {:ok, :equivalent} =
               Beancount.Compare.compare(
                 Beancount.CompareTest.ZeroBalanceA,
                 Beancount.CompareTest.ZeroBalanceB,
                 Beancount.render(@ledger)
               )
    end

    test "cost lots at same commodity and cost merge" do
      assert {:ok, :equivalent} =
               Beancount.Compare.compare(
                 Beancount.CompareTest.CostLotA,
                 Beancount.CompareTest.CostLotB,
                 Beancount.render(@ledger)
               )
    end
  end
end
