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

  test "compare/3 returns a structured diff on mismatch" do
    assert {:error, %Beancount.Property.Diff{callback: :query, message: message}} =
             Beancount.Compare.compare(
               Beancount.FakeEngine,
               Beancount.Engine.Elixir,
               @ledger
             )

    assert message =~ "query"
  end
end
