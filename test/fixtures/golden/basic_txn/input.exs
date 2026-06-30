[
  Beancount.open(~D[2020-01-01], "Assets:Cash"),
  Beancount.open(~D[2020-01-01], "Expenses:Home"),
  Beancount.transaction(~D[2020-01-02], "*", nil, "Buy", [
    Beancount.posting("Assets:Cash", Decimal.new("-10"), "EUR"),
    Beancount.posting("Expenses:Home")
  ])
]
