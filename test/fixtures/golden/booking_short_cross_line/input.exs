[
  Beancount.open(~D[2020-01-01], "Assets:Stocks", ["SHORT"], booking: "FIFO"),
  Beancount.open(~D[2020-01-01], "Assets:Cash"),
  Beancount.transaction(~D[2020-01-02], "*", nil, "Open short", [
    Beancount.posting("Assets:Stocks", Decimal.new("-1"), "SHORT",
      price: %{amount: Decimal.new("10"), currency: "USD", type: :unit}
    ),
    Beancount.posting("Assets:Cash", Decimal.new("10"), "USD")
  ]),
  Beancount.transaction(~D[2020-01-03], "txn", nil, "Close short, cross line", [
    Beancount.posting("Assets:Stocks", Decimal.new("2"), "SHORT",
      price: %{amount: Decimal.new("20"), currency: "USD", type: :unit}
    ),
    Beancount.posting("Assets:Cash")
  ])
]
