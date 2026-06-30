defmodule Beancount.Engine.Elixir.PostingAmountTest do
  use ExUnit.Case, async: true

  alias Beancount.Engine.Elixir.PostingAmount

  test "cost spec contributes cost-basis currency totals" do
    posting =
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        cost: %{amount: Decimal.new("150"), currency: "USD"}
      )

    assert {"USD", amount} = PostingAmount.balance_contribution(posting)
    assert Decimal.equal?(amount, Decimal.new("1500"))
  end

  test "unit price annotation contributes price currency totals" do
    posting =
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        price: %{amount: Decimal.new("10"), currency: "USD", type: :unit}
      )

    assert {"USD", amount} = PostingAmount.balance_contribution(posting)
    assert Decimal.equal?(amount, Decimal.new("100"))
  end

  test "expand_postings/1 infers a single elided amount" do
    postings = [
      Beancount.posting("Assets:Cash", Decimal.new("-10"), "EUR"),
      Beancount.posting("Expenses:Home", nil, nil)
    ]

    [_, home] = PostingAmount.expand_postings(postings)
    assert Decimal.equal?(home.amount, Decimal.new("10"))
    assert home.currency == "EUR"
  end
end
