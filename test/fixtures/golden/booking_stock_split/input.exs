cost_buy = %Beancount.CostSpec{
  per_amount: Decimal.new("10"),
  per_currency: "USD",
  date: ~D[2020-01-02]
}

cost_split = %Beancount.CostSpec{
  per_amount: Decimal.new("5"),
  per_currency: "USD",
  date: ~D[2020-01-02]
}

[
  Beancount.open(~D[2020-01-01], "Assets:Stocks", ["AAPL"], booking: "FIFO"),
  Beancount.open(~D[2020-01-01], "Assets:Cash"),
  Beancount.transaction(~D[2020-01-02], "*", nil, "Buy", [
    Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
      price: %{amount: Decimal.new("10"), currency: "USD", type: :unit}
    ),
    Beancount.posting("Assets:Cash", Decimal.new("-100"), "USD")
  ]),
  Beancount.transaction(~D[2020-01-03], "txn", nil, "Split", [
    Beancount.posting("Assets:Stocks", Decimal.new("-10"), "AAPL",
      cost: cost_buy,
      price: %{amount: Decimal.new("2"), currency: "USD", type: :unit}
    ),
    Beancount.posting("Assets:Stocks", Decimal.new("20"), "AAPL",
      cost: cost_split,
      price: %{amount: Decimal.new("1"), currency: "USD", type: :unit}
    )
  ])
]
