[
  Beancount.open(~D[2025-12-20], "Assets:Cash"),
  Beancount.open(~D[2025-12-20], "Assets:Stocks"),
  Beancount.transaction(~D[2025-12-20], "txn", nil, "Buy", [
    Beancount.posting("Assets:Cash", Decimal.new("-12.08"), "EUR"),
    Beancount.posting("Assets:Stocks", Decimal.new("1.156"), "AAPL",
      price: %{amount: Decimal.new("10.45"), currency: "EUR", type: :unit}
    )
  ])
]
