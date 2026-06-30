[
  Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
  Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
  Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
    Beancount.posting("Assets:Bank", Decimal.new("5000"), "USD"),
    Beancount.posting("Income:Salary", Decimal.new("-5000"), "USD")
  ])
]
