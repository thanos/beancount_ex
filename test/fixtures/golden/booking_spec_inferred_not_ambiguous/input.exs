[
  Beancount.open(~D[2020-01-01], "Assets:Stocks", ["AAPL"], booking: "FIFO"),
  Beancount.open(~D[2020-01-01], "Assets:Cash"),
  Beancount.transaction(~D[2020-01-02], "*", nil, "Buy", [
    Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
      cost: %Beancount.CostSpec{per_amount: Decimal.new("10"), per_currency: "USD"}
    ),
    Beancount.posting("Assets:Cash")
  ]),
  Beancount.transaction(~D[2020-01-03], "txn", nil, "Buy", [
    Beancount.posting("Assets:Stocks", Decimal.new("20"), "AAPL",
      cost: %Beancount.CostSpec{per_amount: Decimal.new("15"), per_currency: "USD"}
    ),
    Beancount.posting("Assets:Cash")
  ]),
  Beancount.transaction(~D[2020-01-04], "txn", nil, "Sell", [
    Beancount.posting("Assets:Stocks", Decimal.new("-10"), "AAPL",
      cost: %Beancount.CostSpec{per_amount: Decimal.new("30"), per_currency: "USD"}
    ),
    Beancount.posting("Assets:Cash")
  ])
]
