[
  Beancount.option("title", "Pad Example"),
  Beancount.option("operating_currency", "USD"),
  Beancount.open(~D[2025-12-20], "Assets:Stocks", [], booking: "FIFO"),
  Beancount.open(~D[2025-12-20], "Assets:Cash", ["USD"]),
  Beancount.open(~D[2025-12-20], "Equity:Opening"),
  Beancount.pad(~D[2025-12-20], "Assets:Cash", "Equity:Opening"),
  Beancount.balance(~D[2025-12-21], "Assets:Cash", Decimal.new("5"), "USD"),
  Beancount.pad(~D[2025-12-21], "Assets:Cash", "Equity:Opening"),
  Beancount.balance(~D[2025-12-22], "Assets:Cash", Decimal.new("10"), "USD")
]
