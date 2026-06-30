[
  Beancount.commodity(~D[2026-01-01], "USD"),
  Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
  Beancount.open(~D[2026-01-01], "Expenses:Food", ["USD"]),
  Beancount.price(~D[2026-01-02], "USD", Decimal.new("1.35"), "CAD"),
  Beancount.transaction(
    ~D[2026-01-05],
    "*",
    "Groceries",
    "Weekly shop",
    [
      Beancount.posting("Expenses:Food", Decimal.new("42.50"), "USD"),
      Beancount.posting("Assets:Bank", Decimal.new("-42.50"), "USD")
    ],
    tags: ["food"],
    links: ["receipt-1"],
    metadata: %{"category" => "household"}
  ),
  Beancount.balance(~D[2026-01-06], "Assets:Bank", Decimal.new("-42.50"), "USD"),
  Beancount.note(~D[2026-01-07], "Assets:Bank", "Reconciled statement"),
  Beancount.event(~D[2026-01-08], "location", "New York"),
  Beancount.custom(~D[2026-01-09], "budget", ["monthly", Decimal.new("400.00"), "USD"]),
  Beancount.close(~D[2026-12-31], "Expenses:Food")
]
