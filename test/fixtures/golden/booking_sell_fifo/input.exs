[
  Beancount.open(~D[2020-01-01], "Assets:Stocks", ["AAPL"], booking: "FIFO"),
  Beancount.open(~D[2020-01-01], "Assets:Cash"),
  Beancount.transaction(~D[2020-01-02], "*", nil, "Buy", [
    Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
      price: %{amount: Decimal.new("10"), currency: "USD", type: :unit}
    ),
    Beancount.posting("Assets:Cash", Decimal.new("-100"), "USD")
  ]),
  Beancount.transaction(~D[2020-01-03], "txn", nil, "Buy", [
    Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
      price: %{amount: Decimal.new("15"), currency: "USD", type: :unit}
    ),
    Beancount.posting("Assets:Cash", Decimal.new("-150"), "USD")
  ]),
  Beancount.transaction(~D[2020-01-04], "txn", nil, "Sell", [
    Beancount.posting("Assets:Stocks", Decimal.new("-15"), "AAPL",
      price: %{amount: Decimal.new("30"), currency: "USD", type: :unit}
    ),
    Beancount.posting("Assets:Cash", Decimal.new("450"), "USD")
  ])
]
