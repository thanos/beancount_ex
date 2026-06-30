[
  Beancount.open(~D[2025-01-01], "Assets:Foo"),
  Beancount.open(~D[2025-01-01], "Assets:Bar"),
  Beancount.transaction(~D[2025-11-21], "txn", nil, "Balance", [
    Beancount.posting("Assets:Foo", nil, "USD",
      price: %{amount: Decimal.new("7"), currency: "EUR", type: :unit}
    ),
    Beancount.posting("Assets:Bar", Decimal.new("1"), "EUR"),
    Beancount.posting("Assets:Bar", Decimal.new("0.01"), "USD"),
    Beancount.posting("Assets:Bar", Decimal.new("-0.01"), "USD")
  ])
]
