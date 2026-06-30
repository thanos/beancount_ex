[
  Beancount.open(~D[2025-12-10], "Assets:Stocks", [], booking: "FIFO"),
  Beancount.open(~D[2025-12-10], "Assets:Cash"),
  Beancount.transaction(~D[2025-12-10], "txn", nil, "Buy", [
    Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
      cost: %Beancount.CostSpec{per_amount: Decimal.new("2"), per_currency: "USD"}
    ),
    Beancount.posting("Assets:Cash")
  ]),
  Beancount.transaction(~D[2025-12-11], "txn", nil, "Sell", [
    Beancount.posting("Assets:Stocks", Decimal.new("-5"), "AAPL",
      cost: %Beancount.CostSpec{per_amount: Decimal.new("2"), per_currency: "USD"},
      price: %{amount: Decimal.new("3"), currency: "USD", type: :unit}
    ),
    Beancount.posting("Assets:Cash", Decimal.new("15"), "USD")
  ]),
  Beancount.transaction(~D[2025-12-11], "txn", nil, "Sell", [
    Beancount.posting("Assets:Stocks", Decimal.new("-5"), "AAPL",
      cost: %Beancount.CostSpec{per_amount: Decimal.new("4"), per_currency: "USD"}
    ),
    Beancount.posting("Assets:Cash", Decimal.new("20"), "USD")
  ])
]
