[
  Beancount.open(~D[2025-12-20], "Assets:Stocks", [], booking: "FIFO"),
  Beancount.open(~D[2025-12-20], "Assets:Cash"),
  Beancount.open(~D[2025-12-20], "Equity:Opening"),
  Beancount.pad(~D[2025-12-20], "Assets:Stocks", "Equity:Opening"),
  Beancount.balance(~D[2025-12-21], "Assets:Stocks", Decimal.new("5"), "AAPL"),
  Beancount.pad(~D[2025-12-20], "Assets:Cash", "Equity:Opening"),
  Beancount.balance(~D[2025-12-21], "Assets:Cash", Decimal.new("5"), "USD")
]
