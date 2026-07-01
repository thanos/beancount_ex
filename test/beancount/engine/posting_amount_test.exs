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

  test "transaction_totals/1 aggregates expanded postings" do
    postings = [
      Beancount.posting("Assets:Cash", Decimal.new("10"), "USD"),
      Beancount.posting("Income:Salary", Decimal.new("-10"), "USD")
    ]

    totals = PostingAmount.transaction_totals(postings)
    assert Decimal.equal?(Map.fetch!(totals, "USD"), 0)
  end

  test "total price annotation contributes price currency totals" do
    posting =
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        price: %{amount: Decimal.new("1500"), currency: "USD", type: :total}
      )

    assert {"USD", amount} = PostingAmount.balance_contribution(posting)
    assert Decimal.equal?(amount, Decimal.new("1500"))
  end

  test "cost spec with total amount contributes total currency" do
    posting =
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        cost: %Beancount.CostSpec{
          total_amount: Decimal.new("1500"),
          total_currency: "USD"
        }
      )

    assert {"USD", amount} = PostingAmount.balance_contribution(posting)
    assert Decimal.equal?(amount, Decimal.new("1500"))
  end

  test "expand_postings/1 leaves postings unchanged when inference is ambiguous" do
    postings = [
      Beancount.posting("Assets:Cash", Decimal.new("-10"), "EUR"),
      Beancount.posting("Expenses:Home", nil, nil),
      Beancount.posting("Income:Salary", Decimal.new("5"), "USD")
    ]

    assert PostingAmount.expand_postings(postings) == postings
  end

  test "balance_contribution/1 returns nil for postings without amounts" do
    posting = %Beancount.Directives.Posting{
      account: "Assets:Cash",
      amount: nil,
      currency: nil,
      cost: nil,
      price: nil,
      flag: nil,
      metadata: %{}
    }

    assert PostingAmount.balance_contribution(posting) == nil
  end
end
