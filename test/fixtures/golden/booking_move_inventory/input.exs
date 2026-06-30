cost = %Beancount.CostSpec{
  per_amount: Decimal.new("10"),
  per_currency: "USD",
  date: ~D[2020-01-02]
}

[
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
