defmodule Beancount.DirectivesTest do
  use ExUnit.Case, async: true

  alias Beancount.Directive

  defp render(directive), do: directive |> Directive.to_bean() |> IO.iodata_to_binary()

  test "open with booking method and no currencies" do
    open = Beancount.open(~D[2026-01-01], "Assets:Bank", [], booking: "STRICT")
    assert render(open) == ~s(2026-01-01 open Assets:Bank "STRICT")
  end

  test "open with multiple currencies" do
    open = Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD", "EUR"])
    assert render(open) == "2026-01-01 open Assets:Bank USD,EUR"
  end

  test "close" do
    assert render(Beancount.close(~D[2026-12-31], "Assets:Bank")) ==
             "2026-12-31 close Assets:Bank"
  end

  test "commodity" do
    assert render(Beancount.commodity(~D[2026-01-01], "USD")) == "2026-01-01 commodity USD"
  end

  test "balance" do
    directive = Beancount.balance(~D[2026-01-31], "Assets:Bank", Decimal.new("100.00"), "USD")
    assert render(directive) == "2026-01-31 balance Assets:Bank  100.00 USD"
  end

  test "balance with tolerance" do
    directive =
      Beancount.balance(~D[2026-01-31], "Assets:Bank", Decimal.new("1.5"), "USD",
        tolerance: Decimal.new("0.5")
      )

    assert render(directive) == "2026-01-31 balance Assets:Bank  1.5 ~ 0.5 USD"
  end

  test "posting amount without currency but with price" do
    posting =
      Beancount.posting("Assets:Foo", Decimal.new("1"), nil,
        price: %{amount: Decimal.new("1"), currency: "USD", type: :unit}
      )

    assert render(posting) == "  Assets:Foo  1 @ 1 USD"
  end

  test "posting with date-only cost" do
    posting =
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        cost: %Beancount.CostSpec{date: ~D[2020-01-01]},
        price: %{amount: Decimal.new("15"), currency: "USD", type: :unit}
      )

    assert render(posting) =~ "{2020-01-01} @ 15 USD"
  end

  test "posting with label-only cost" do
    posting =
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        cost: %Beancount.CostSpec{label: "magic lot"},
        price: %{amount: Decimal.new("10"), currency: "USD", type: :unit}
      )

    assert render(posting) =~ ~s({"magic lot"} @ 10 USD)
  end

  test "price" do
    directive = Beancount.price(~D[2026-01-01], "USD", Decimal.new("1.20"), "CAD")
    assert render(directive) == "2026-01-01 price USD 1.20 CAD"
  end

  test "note" do
    assert render(Beancount.note(~D[2026-01-01], "Assets:Bank", "hi")) ==
             ~s(2026-01-01 note Assets:Bank "hi")
  end

  test "document" do
    assert render(Beancount.document(~D[2026-01-01], "Assets:Bank", "a.pdf")) ==
             ~s(2026-01-01 document Assets:Bank "a.pdf")
  end

  test "event" do
    assert render(Beancount.event(~D[2026-01-01], "location", "NYC")) ==
             ~s(2026-01-01 event "location" "NYC")
  end

  test "custom with values" do
    directive = Beancount.custom(~D[2026-01-01], "budget", [Decimal.new("400"), "USD"])
    assert render(directive) == ~s(2026-01-01 custom "budget" 400 "USD")
  end

  test "custom with account, tag, and amount values" do
    directive =
      Beancount.custom(~D[2026-01-01], "budget", [
        Beancount.account_value("Expenses:Food"),
        Beancount.tag_value("trip"),
        Beancount.amount_value(Decimal.new("400"), "USD")
      ])

    assert render(directive) ==
             ~s(2026-01-01 custom "budget" Expenses:Food #trip 400 USD)
  end

  test "document with metadata" do
    directive =
      Beancount.document(~D[2026-01-01], "Assets:Bank", "a.pdf", metadata: %{"source" => "scan"})

    assert render(directive) ==
             """
             2026-01-01 document Assets:Bank "a.pdf"
               source: "scan"
             """
             |> String.trim_trailing()
  end

  test "event with metadata" do
    directive =
      Beancount.event(~D[2026-01-01], "location", "NYC", metadata: %{"country" => "US"})

    rendered = render(directive)
    assert rendered =~ ~s(2026-01-01 event "location" "NYC")
    assert rendered =~ ~s(country: "US")
  end

  test "pad directive" do
    assert render(Beancount.pad(~D[2025-12-20], "Assets:Cash", "Equity:Opening")) ==
             "2025-12-20 pad Assets:Cash Equity:Opening"
  end

  test "include directive" do
    assert render(Beancount.include("accounts.bean")) == ~s(include "accounts.bean")
  end

  test "option directive" do
    assert render(Beancount.option("title", "My Ledger")) ==
             ~s(option "title" "My Ledger")

    assert render(Beancount.option("infer_tolerance_from_cost", true)) ==
             "option \"infer_tolerance_from_cost\" TRUE"
  end

  test "posting with rich cost and price" do
    cost = %Beancount.CostSpec{
      per_amount: Decimal.new("10"),
      per_currency: "USD",
      date: ~D[2020-01-02]
    }

    txn =
      Beancount.transaction(~D[2020-01-03], "txn", nil, "Move", [
        Beancount.posting("Assets:Stocks", Decimal.new("-10"), "AAPL",
          cost: cost,
          price: %{amount: Decimal.new("1"), currency: "USD", type: :unit}
        ),
        Beancount.posting("Assets:MoreStocks", Decimal.new("10"), "AAPL",
          cost: cost,
          price: %{amount: Decimal.new("1"), currency: "USD", type: :unit}
        )
      ])

    rendered = Beancount.render([txn])
    assert rendered =~ "{10 USD, 2020-01-02} @ 1 USD"
    assert rendered =~ "Assets:Stocks"
    assert rendered =~ "Assets:MoreStocks"
  end

  test "posting flag and total price annotation" do
    txn =
      Beancount.transaction(~D[2026-01-01], "*", nil, "X", [
        Beancount.posting("Assets:Bank", Decimal.new("5"), "USD", flag: "!"),
        Beancount.posting("Assets:Other", Decimal.new("-5"), "USD",
          price: %{amount: Decimal.new("5"), currency: "EUR", type: :total}
        )
      ])

    rendered = Beancount.render([txn])
    assert rendered =~ "  ! Assets:Bank"
    assert rendered =~ "@@ 5 EUR"
  end

  test "custom with no values" do
    assert render(Beancount.custom(~D[2026-01-01], "ping")) == ~s(2026-01-01 custom "ping")
  end

  test "standalone posting renders an indented line" do
    posting = Beancount.posting("Assets:Bank", Decimal.new("5"), "USD")
    assert render(posting) == "  Assets:Bank  5 USD"
  end

  test "posting with legacy cost map" do
    posting =
      Beancount.posting("Assets:Stock", Decimal.new("10"), "AAPL",
        cost: %{amount: Decimal.new("150"), currency: "USD"}
      )

    assert render(posting) =~ "{150 USD}"
  end

  test "query directive" do
    directive =
      Beancount.query_directive(~D[2026-01-01], "monthly", "SELECT account",
        metadata: %{
          "author" => "me"
        }
      )

    rendered = render(directive)

    assert rendered =~ ~s(2026-01-01 query "monthly" "SELECT account")
    assert rendered =~ ~s(author: "me")
  end

  test "plugin directive with and without config" do
    assert render(Beancount.plugin("beancount.plugins.auto")) ==
             ~s(plugin "beancount.plugins.auto")

    assert render(Beancount.plugin("beancount.plugins.auto", "Assets:Cash")) ==
             ~s(plugin "beancount.plugins.auto" "Assets:Cash")
  end

  test "pushtag and poptag directives" do
    assert render(Beancount.push_tag("trip")) == "pushtag #trip"
    assert render(Beancount.pop_tag("trip")) == "poptag #trip"
  end
end
