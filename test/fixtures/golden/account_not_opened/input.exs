[
  Beancount.transaction(~D[2020-01-02], "*", nil, "Buy", [
    Beancount.posting("Assets:Cash", Decimal.new("-10"), "EUR"),
    Beancount.posting("Expenses:Home")
  ])
]
