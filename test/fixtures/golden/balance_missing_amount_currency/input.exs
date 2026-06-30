[
  Beancount.open(~D[2025-12-19], "Assets:Foo"),
  Beancount.open(~D[2025-12-19], "Assets:Bar"),
  Beancount.transaction(~D[2025-12-19], "txn", nil, "Foo", [
    Beancount.posting("Assets:Foo", Decimal.new("1"), nil,
      price: %{amount: Decimal.new("1"), currency: "USD", type: :unit}
    ),
    Beancount.posting("Assets:Bar")
  ])
]
