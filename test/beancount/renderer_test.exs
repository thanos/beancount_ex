defmodule Beancount.RendererTest do
  use ExUnit.Case, async: true

  alias Beancount.Renderer

  doctest Beancount.Renderer

  describe "format helpers" do
    test "format_date/1" do
      assert Renderer.format_date(~D[2026-02-09]) == "2026-02-09"
    end

    test "format_decimal/1 avoids scientific notation" do
      assert Renderer.format_decimal(Decimal.new("1000000")) == "1000000"
      assert Renderer.format_decimal(Decimal.new("-0.5")) == "-0.5"
    end

    test "quote_string/1 escapes quotes and backslashes" do
      assert Renderer.quote_string(~S(a"b\c)) == ~S("a\"b\\c")
    end

    test "format_value/1 handles supported scalars" do
      assert Renderer.format_value("x") == ~S("x")
      assert Renderer.format_value(Decimal.new("1.5")) == "1.5"
      assert Renderer.format_value(~D[2026-01-01]) == "2026-01-01"
      assert Renderer.format_value(true) == "TRUE"
      assert Renderer.format_value(false) == "FALSE"
      assert Renderer.format_value(42) == "42"
      assert Renderer.format_value(:Assets) == "Assets"
      assert Renderer.format_value(1.5) == "1.5"
    end

    test "format_value/1 raises for nil and unsupported terms" do
      assert_raise ArgumentError, fn -> Renderer.format_value(nil) end
      assert_raise ArgumentError, fn -> Renderer.format_value([1, 2]) end
    end
  end

  describe "metadata rendering" do
    test "keys are sorted for determinism" do
      directive =
        Beancount.commodity(~D[2026-01-01], "USD", metadata: %{"z" => "1", "a" => "2"})

      assert Beancount.render([directive]) ==
               """
               2026-01-01 commodity USD
                 a: "2"
                 z: "1"
               """
    end
  end

  describe "posting features" do
    test "renders cost and price annotations" do
      txn =
        Beancount.transaction(~D[2026-01-01], "*", nil, "Buy", [
          Beancount.posting("Assets:Stock", Decimal.new("10"), "AAPL",
            cost: %{amount: Decimal.new("150.00"), currency: "USD"}
          ),
          Beancount.posting("Assets:Cash", Decimal.new("-1500.00"), "USD",
            price: %{amount: Decimal.new("1.0"), currency: "USD", type: :unit}
          )
        ])

      rendered = Beancount.render([txn])
      assert rendered =~ "{150.00 USD}"
      assert rendered =~ "@ 1.0 USD"
    end

    test "renders inventory cost with date and FIFO open" do
      cost = %Beancount.CostSpec{
        per_amount: Decimal.new("10"),
        per_currency: "USD",
        date: ~D[2020-01-02]
      }

      ledger = [
        Beancount.open(~D[2020-01-01], "Assets:Stocks", ["AAPL"], booking: "FIFO"),
        Beancount.open(~D[2020-01-01], "Assets:MoreStocks", ["AAPL"], booking: "FIFO"),
        Beancount.open(~D[2020-01-01], "Assets:Cash", ["USD"]),
        Beancount.transaction(~D[2020-01-02], "*", nil, "Buy", [
          Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
            price: %{amount: Decimal.new("10"), currency: "USD", type: :unit}
          ),
          Beancount.posting("Assets:Cash", Decimal.new("-100"), "USD")
        ]),
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
      ]

      rendered = Beancount.render(ledger)
      assert rendered =~ ~s(2020-01-01 open Assets:Stocks AAPL "FIFO")
      assert rendered =~ "{10 USD, 2020-01-02} @ 1 USD"
    end

    test "renders option and include at top of ledger" do
      ledger = [
        Beancount.option("title", "Test Ledger"),
        Beancount.option("operating_currency", "USD"),
        Beancount.include("accounts.bean"),
        Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"])
      ]

      rendered = Beancount.render(ledger)
      assert rendered =~ ~s(option "title" "Test Ledger")
      assert rendered =~ ~s(option "operating_currency" "USD")
      assert rendered =~ ~s(include "accounts.bean")
    end

    test "renders posting-level metadata indented" do
      txn =
        Beancount.transaction(~D[2026-01-01], "*", nil, "X", [
          Beancount.posting("Assets:Bank", Decimal.new("1"), "USD", metadata: %{"k" => "v"}),
          Beancount.posting("Equity:Open", Decimal.new("-1"), "USD")
        ])

      assert Beancount.render([txn]) =~ "    k: \"v\""
    end
  end
end
