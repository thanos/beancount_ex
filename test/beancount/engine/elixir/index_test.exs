defmodule Beancount.Engine.Elixir.IndexTest do
  use ExUnit.Case, async: true

  alias Beancount.Engine.Elixir.{FactBase, Index, Ledger}

  test "postings_for_account/3 filters in memory when index is nil" do
    ledger = Ledger.new()

    directives = [
      Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
      Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
        Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
        Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
      ])
    ]

    ledger = Ledger.process(ledger, directives)
    fact_base = FactBase.from_ledger(ledger, directives)

    postings = Index.postings_for_account(nil, fact_base, "Assets:Bank")
    assert length(postings) == 1
    assert hd(postings).account == "Assets:Bank"
  end

  test "create/1 and destroy/1 manage ETS tables" do
    directives =
      for index <- 1..1_001,
          do: Beancount.open(~D[2026-01-01], "Assets:Tmp#{index}", ["USD"])

    ledger = Ledger.process(Ledger.new(), directives)
    fact_base = FactBase.from_ledger(ledger, directives)
    index = Index.create(fact_base)

    assert Index.postings_for_account(index, fact_base, "Assets:Tmp1") == []
    assert :ok = Index.destroy(index)
    assert :ok = Index.destroy(nil)
  end

  test "create/1 indexes postings for account lookup" do
    directives =
      [Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"])] ++
        (for index <- 1..1_001 do
           [
             Beancount.open(~D[2026-01-01], "Assets:Tmp#{index}", ["USD"]),
             Beancount.transaction(~D[2026-01-31], "*", nil, "Seed", [
               Beancount.posting("Assets:Tmp#{index}", Decimal.new("1"), "USD"),
               Beancount.posting("Income:Salary", Decimal.new("-1"), "USD")
             ])
           ]
         end
         |> List.flatten())

    ledger = Ledger.process(Ledger.new(), directives)
    fact_base = FactBase.from_ledger(ledger, directives)
    index = Index.create(fact_base)

    postings = Index.postings_for_account(index, fact_base, "Assets:Tmp1")
    assert length(postings) == 1
    assert :ok = Index.destroy(index)
  end
end
