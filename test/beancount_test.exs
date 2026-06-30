defmodule BeancountTest do
  use ExUnit.Case, async: true

  doctest Beancount

  alias Beancount.Directives.{Open, Posting, Transaction}

  describe "constructors" do
    test "open/4 builds an Open struct" do
      open = Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"], booking: "STRICT")
      assert %Open{account: "Assets:Bank", currencies: ["USD"], booking: "STRICT"} = open
    end

    test "transaction/6 builds a Transaction with options" do
      txn =
        Beancount.transaction(~D[2026-01-31], "*", "Payee", "Narration", [],
          tags: ["t"],
          links: ["l"],
          metadata: %{"k" => "v"}
        )

      assert %Transaction{tags: ["t"], links: ["l"], metadata: %{"k" => "v"}} = txn
    end

    test "posting/4 builds a Posting" do
      assert %Posting{account: "Assets:Bank", amount: amount, currency: "USD"} =
               Beancount.posting("Assets:Bank", Decimal.new("5000"), "USD")

      assert Decimal.equal?(amount, Decimal.new("5000"))
    end

    test "posting with elided amount" do
      assert %Posting{amount: nil, currency: nil} = Beancount.posting("Assets:Bank")
    end
  end

  describe "render/1" do
    test "renders the canonical salary example" do
      ledger = [
        Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
        Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
        Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
          Beancount.posting("Assets:Bank", Decimal.new("5000"), "USD"),
          Beancount.posting("Income:Salary", Decimal.new("-5000"), "USD")
        ])
      ]

      expected = """
      2026-01-01 open Assets:Bank USD

      2026-01-01 open Income:Salary USD

      2026-01-31 * "Employer" "Salary"
        Assets:Bank     5000 USD
        Income:Salary  -5000 USD
      """

      assert Beancount.render(ledger) == expected
    end

    test "is deterministic" do
      ledger = [
        Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
        Beancount.transaction(~D[2026-01-31], "*", nil, "Solo", [
          Beancount.posting("Assets:Bank", Decimal.new("10"), "USD"),
          Beancount.posting("Equity:Opening", Decimal.new("-10"), "USD")
        ])
      ]

      assert Beancount.render(ledger) == Beancount.render(ledger)
    end

    test "empty stream renders to empty string" do
      assert Beancount.render([]) == ""
    end

    test "transaction without payee renders only narration" do
      txn = Beancount.transaction(~D[2026-01-01], "!", nil, "Just narration", [])
      assert Beancount.render([txn]) == ~s(2026-01-01 ! "Just narration"\n)
    end
  end
end
