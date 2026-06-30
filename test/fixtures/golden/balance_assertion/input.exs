[
  Beancount.open(~D[2025-11-21], "Assets:Foo", ["USD"]),
  Beancount.open(~D[2025-11-21], "Expenses:Bar"),
  Beancount.transaction(~D[2025-11-22], "*", nil, "", [
    Beancount.posting("Assets:Foo", Decimal.new("1"), "USD"),
    Beancount.posting("Expenses:Bar")
  ]),
  Beancount.balance(~D[2025-11-23], "Assets", Decimal.new("-1"), "USD"),
  Beancount.balance(~D[2025-11-23], "Assets:Foo", Decimal.new("1"), "EUR"),
  Beancount.balance(~D[2025-11-23], "Assets:Foo", Decimal.new("1"), "USD"),
  Beancount.balance(~D[2025-11-23], "Assets:Foo", Decimal.new("2"), "USD"),
  Beancount.balance(~D[2025-11-23], "Assets:Foo", Decimal.new("1.1"), "USD"),
  Beancount.balance(~D[2025-11-23], "Assets:Foo", Decimal.new("1.2"), "USD"),
  Beancount.balance(~D[2025-11-23], "Assets:Foo", Decimal.new("1.5"), "USD",
    tolerance: Decimal.new("0.5")
  ),
  Beancount.balance(~D[2025-11-23], "Assets:Foo", Decimal.new("1.5"), "USD",
    tolerance: Decimal.new("0.3")
  )
]
