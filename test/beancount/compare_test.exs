defmodule Beancount.CompareTest do
  use ExUnit.Case, async: false

  setup do
    unless Process.whereis(Beancount.FakeEngine) do
      {:ok, _} = Beancount.FakeEngine.start_link()
    end

    Beancount.FakeEngine.reset!()
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
end
