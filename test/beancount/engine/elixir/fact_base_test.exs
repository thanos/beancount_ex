defmodule Beancount.Engine.Elixir.FactBaseTest do
  use ExUnit.Case, async: true

  alias Beancount.Engine.Elixir.{FactBase, Ledger}

  test "from_ledger/2 captures opens, postings, lots, and transaction accounts" do
    directives = [
      Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
      Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
      Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
      Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
        Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
        Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
      ])
    ]

    ledger = Ledger.process(Ledger.new(), directives)
    fact_base = FactBase.from_ledger(ledger, directives)

    assert Map.has_key?(fact_base.opens, "Assets:Bank")
    assert MapSet.member?(fact_base.transaction_accounts, "Assets:Bank")
    assert length(fact_base.postings) == 2
    assert [%{account: "Assets:Bank", currency: "USD"} | _] = fact_base.postings
    assert Enum.any?(fact_base.lots, &(&1.account == "Assets:Bank"))
  end

  test "from_ledger/2 records lots without cost metadata" do
    directives = [
      Beancount.open(~D[2026-01-01], "Assets:Cash", ["USD"]),
      Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
      Beancount.transaction(~D[2026-01-31], "*", nil, "Deposit", [
        Beancount.posting("Assets:Cash", Decimal.new("5"), "USD"),
        Beancount.posting("Equity:Opening", Decimal.new("-5"), "USD")
      ])
    ]

    ledger = Ledger.process(Ledger.new(), directives)
    fact_base = FactBase.from_ledger(ledger, directives)

    cash_lot = Enum.find(fact_base.lots, &(&1.account == "Assets:Cash"))
    assert %{date: nil, label: nil, account: "Assets:Cash"} = cash_lot
  end

  test "from_ledger/2 ignores non-material postings for transaction accounts" do
    directives = [
      Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
      Beancount.transaction(~D[2026-01-31], "*", nil, "Note only", [
        %Beancount.Directives.Posting{
          account: "Assets:Bank",
          amount: nil,
          currency: nil,
          cost: nil,
          price: nil,
          flag: nil,
          metadata: %{}
        }
      ])
    ]

    ledger = Ledger.process(Ledger.new(), directives)
    fact_base = FactBase.from_ledger(ledger, directives)

    refute MapSet.member?(fact_base.transaction_accounts, "Assets:Bank")
    assert [%{amount: nil}] = fact_base.postings
  end
end
