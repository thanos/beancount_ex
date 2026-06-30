# One-off generator: creates golden input.exs from embedded definitions.
# Run: mix run scripts/generate_turbobean_golden_inputs.exs

cases = %{
  "account_not_opened" => """
  [
    Beancount.transaction(~D[2020-01-02], "*", nil, "Buy", [
      Beancount.posting("Assets:Cash", Decimal.new("-10"), "EUR"),
      Beancount.posting("Expenses:Home")
    ])
  ]
  """,

  "basic_txn" => """
  [
    Beancount.open(~D[2020-01-01], "Assets:Cash"),
    Beancount.open(~D[2020-01-01], "Expenses:Home"),
    Beancount.transaction(~D[2020-01-02], "*", nil, "Buy", [
      Beancount.posting("Assets:Cash", Decimal.new("-10"), "EUR"),
      Beancount.posting("Expenses:Home")
    ])
  ]
  """,

  "double_open" => """
  [
    Beancount.open(~D[2025-11-21], "Assets:Foo"),
    Beancount.open(~D[2025-11-22], "Assets:Foo")
  ]
  """,

  "balance_single" => """
  [
    Beancount.transaction(~D[2025-11-21], "txn", nil, "Balance", [
      Beancount.posting("Assets:Foo")
    ])
  ]
  """,

  "pad_not_plain" => """
  [
    Beancount.open(~D[2025-12-20], "Assets:Stocks", [], booking: "FIFO"),
    Beancount.open(~D[2025-12-20], "Assets:Cash"),
    Beancount.open(~D[2025-12-20], "Equity:Opening"),
    Beancount.pad(~D[2025-12-20], "Assets:Stocks", "Equity:Opening"),
    Beancount.balance(~D[2025-12-21], "Assets:Stocks", Decimal.new("5"), "AAPL"),
    Beancount.pad(~D[2025-12-20], "Assets:Cash", "Equity:Opening"),
    Beancount.balance(~D[2025-12-21], "Assets:Cash", Decimal.new("5"), "USD")
  ]
  """,

  "include_not_found" => """
  [
    Beancount.include("nonexistent.bean"),
    Beancount.open(~D[2024-01-01], "Assets:Checking")
  ]
  """,

  "balance_assertion" => """
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
  """,

  "balance_missing_amount_currency" => """
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
  """,

  "balance_interpolation" => """
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
  """,

  "tolerance" => """
  [
    Beancount.open(~D[2025-12-20], "Assets:Cash"),
    Beancount.open(~D[2025-12-20], "Assets:Stocks"),
    Beancount.transaction(~D[2025-12-20], "txn", nil, "Buy", [
      Beancount.posting("Assets:Cash", Decimal.new("-12.08"), "EUR"),
      Beancount.posting("Assets:Stocks", Decimal.new("1.156"), "AAPL",
        price: %{amount: Decimal.new("10.45"), currency: "EUR", type: :unit}
      )
    ])
  ]
  """,

  "booking_sell_fifo" => """
  [
    Beancount.open(~D[2020-01-01], "Assets:Stocks", ["AAPL"], booking: "FIFO"),
    Beancount.open(~D[2020-01-01], "Assets:Cash"),
    Beancount.transaction(~D[2020-01-02], "*", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        price: %{amount: Decimal.new("10"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-100"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-03], "txn", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        price: %{amount: Decimal.new("15"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-150"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-04], "txn", nil, "Sell", [
      Beancount.posting("Assets:Stocks", Decimal.new("-15"), "AAPL",
        price: %{amount: Decimal.new("30"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("450"), "USD")
    ])
  ]
  """,

  "booking_lifo" => """
  [
    Beancount.open(~D[2020-01-01], "Assets:Stocks", ["AAPL"], booking: "LIFO"),
    Beancount.open(~D[2020-01-01], "Assets:Cash"),
    Beancount.transaction(~D[2020-01-02], "*", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        price: %{amount: Decimal.new("10"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-100"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-03], "txn", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        price: %{amount: Decimal.new("15"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-150"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-04], "txn", nil, "Sell", [
      Beancount.posting("Assets:Stocks", Decimal.new("-10"), "AAPL",
        price: %{amount: Decimal.new("30"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("300"), "USD")
    ])
  ]
  """,

  "booking_lifo_short" => """
  [
    Beancount.open(~D[2020-01-01], "Assets:Stocks", ["AAPL"], booking: "LIFO"),
    Beancount.open(~D[2020-01-01], "Assets:Cash"),
    Beancount.transaction(~D[2020-01-02], "*", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("-10"), "AAPL",
        price: %{amount: Decimal.new("10"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("100"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-03], "txn", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("-10"), "AAPL",
        price: %{amount: Decimal.new("15"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("150"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-04], "txn", nil, "Sell", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        price: %{amount: Decimal.new("30"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-300"), "USD")
    ])
  ]
  """,

  "booking_strict" => """
  [
    Beancount.open(~D[2020-01-01], "Assets:Stocks", ["AAPL"], booking: "STRICT"),
    Beancount.open(~D[2020-01-01], "Assets:Cash"),
    Beancount.transaction(~D[2020-01-02], "*", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        price: %{amount: Decimal.new("10"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-100"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-03], "txn", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        price: %{amount: Decimal.new("15"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-150"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-04], "txn", nil, "Sell", [
      Beancount.posting("Assets:Stocks", Decimal.new("-10"), "AAPL",
        cost: %Beancount.CostSpec{per_amount: Decimal.new("10"), per_currency: "USD"},
        price: %{amount: Decimal.new("30"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("300"), "USD")
    ])
  ]
  """,

  "booking_strict_fail" => """
  [
    Beancount.open(~D[2020-01-01], "Assets:Stocks", ["AAPL"], booking: "STRICT"),
    Beancount.open(~D[2020-01-01], "Assets:Cash"),
    Beancount.transaction(~D[2020-01-02], "*", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        price: %{amount: Decimal.new("10"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-100"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-03], "txn", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        price: %{amount: Decimal.new("15"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-150"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-04], "txn", nil, "Sell", [
      Beancount.posting("Assets:Stocks", Decimal.new("-10"), "AAPL",
        price: %{amount: Decimal.new("30"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("300"), "USD")
    ])
  ]
  """,

  "booking_strict_miss" => """
  [
    Beancount.open(~D[2020-01-01], "Assets:Stocks", ["AAPL"], booking: "STRICT"),
    Beancount.open(~D[2020-01-01], "Assets:Cash"),
    Beancount.transaction(~D[2020-01-02], "*", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        price: %{amount: Decimal.new("10"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-100"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-03], "txn", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        price: %{amount: Decimal.new("15"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-150"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-04], "txn", nil, "Sell", [
      Beancount.posting("Assets:Stocks", Decimal.new("-10"), "AAPL",
        cost: %Beancount.CostSpec{per_amount: Decimal.new("1"), per_currency: "USD"},
        price: %{amount: Decimal.new("30"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("300"), "USD")
    ])
  ]
  """,

  "booking_strict_cancel_all" => """
  [
    Beancount.open(~D[2020-01-01], "Assets:Stocks", ["AAPL"], booking: "STRICT"),
    Beancount.open(~D[2020-01-01], "Assets:Cash"),
    Beancount.transaction(~D[2020-01-02], "*", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        price: %{amount: Decimal.new("10"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-100"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-03], "txn", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        price: %{amount: Decimal.new("15"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-150"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-04], "txn", nil, "Sell", [
      Beancount.posting("Assets:Stocks", Decimal.new("-20"), "AAPL",
        price: %{amount: Decimal.new("30"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("600"), "USD")
    ])
  ]
  """,

  "booking_stock_split" => """
  cost_buy = %Beancount.CostSpec{
    per_amount: Decimal.new("10"),
    per_currency: "USD",
    date: ~D[2020-01-02]
  }

  cost_split = %Beancount.CostSpec{
    per_amount: Decimal.new("5"),
    per_currency: "USD",
    date: ~D[2020-01-02]
  }

  [
    Beancount.open(~D[2020-01-01], "Assets:Stocks", ["AAPL"], booking: "FIFO"),
    Beancount.open(~D[2020-01-01], "Assets:Cash"),
    Beancount.transaction(~D[2020-01-02], "*", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        price: %{amount: Decimal.new("10"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-100"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-03], "txn", nil, "Split", [
      Beancount.posting("Assets:Stocks", Decimal.new("-10"), "AAPL",
        cost: cost_buy,
        price: %{amount: Decimal.new("2"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Stocks", Decimal.new("20"), "AAPL",
        cost: cost_split,
        price: %{amount: Decimal.new("1"), currency: "USD", type: :unit}
      )
    ])
  ]
  """,

  "booking_spec_inferred_not_ambiguous" => """
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
  """,

  "booking_infer_price" => """
  [
    Beancount.open(~D[2025-12-10], "Assets:Stocks", [], booking: "FIFO"),
    Beancount.open(~D[2025-12-10], "Assets:Cash"),
    Beancount.transaction(~D[2025-12-10], "txn", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        cost: %Beancount.CostSpec{per_amount: Decimal.new("2"), per_currency: "USD"}
      ),
      Beancount.posting("Assets:Cash")
    ]),
    Beancount.transaction(~D[2025-12-11], "txn", nil, "Sell", [
      Beancount.posting("Assets:Stocks", Decimal.new("-5"), "AAPL",
        cost: %Beancount.CostSpec{per_amount: Decimal.new("2"), per_currency: "USD"},
        price: %{amount: Decimal.new("3"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("15"), "USD")
    ]),
    Beancount.transaction(~D[2025-12-11], "txn", nil, "Sell", [
      Beancount.posting("Assets:Stocks", Decimal.new("-5"), "AAPL",
        cost: %Beancount.CostSpec{per_amount: Decimal.new("4"), per_currency: "USD"}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("20"), "USD")
    ])
  ]
  """,

  "booking_short_cross_line" => """
  [
    Beancount.open(~D[2020-01-01], "Assets:Stocks", ["SHORT"], booking: "FIFO"),
    Beancount.open(~D[2020-01-01], "Assets:Cash"),
    Beancount.transaction(~D[2020-01-02], "*", nil, "Open short", [
      Beancount.posting("Assets:Stocks", Decimal.new("-1"), "SHORT",
        price: %{amount: Decimal.new("10"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("10"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-03], "txn", nil, "Close short, cross line", [
      Beancount.posting("Assets:Stocks", Decimal.new("2"), "SHORT",
        price: %{amount: Decimal.new("20"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash")
    ])
  ]
  """,

  "booking_add_override" => """
  [
    Beancount.open(~D[2020-01-01], "Assets:Stocks", ["AAPL"], booking: "FIFO"),
    Beancount.open(~D[2020-01-01], "Assets:Cash"),
    Beancount.transaction(~D[2020-01-02], "*", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        price: %{amount: Decimal.new("10"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-100"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-03], "txn", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        cost: %Beancount.CostSpec{date: ~D[2020-01-01]},
        price: %{amount: Decimal.new("15"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-150"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-04], "txn", nil, "Sell", [
      Beancount.posting("Assets:Stocks", Decimal.new("-10"), "AAPL",
        price: %{amount: Decimal.new("30"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("300"), "USD")
    ])
  ]
  """,

  "booking_spec_ambiguous" => """
  lot = %Beancount.CostSpec{label: "magic lot"}

  [
    Beancount.open(~D[2020-01-01], "Assets:Stocks", ["AAPL"], booking: "STRICT"),
    Beancount.open(~D[2020-01-01], "Assets:Cash"),
    Beancount.transaction(~D[2020-01-02], "*", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        cost: lot,
        price: %{amount: Decimal.new("10"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-100"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-03], "txn", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        cost: lot,
        price: %{amount: Decimal.new("15"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-150"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-04], "txn", nil, "Sell", [
      Beancount.posting("Assets:Stocks", Decimal.new("-10"), "AAPL",
        cost: lot,
        price: %{amount: Decimal.new("30"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("300"), "USD")
    ])
  ]
  """,

  "booking_spec_too_small" => """
  lot = %Beancount.CostSpec{label: "magic lot"}

  [
    Beancount.open(~D[2020-01-01], "Assets:Stocks", ["AAPL"], booking: "STRICT"),
    Beancount.open(~D[2020-01-01], "Assets:Cash"),
    Beancount.transaction(~D[2020-01-02], "*", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        cost: lot,
        price: %{amount: Decimal.new("10"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-100"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-03], "txn", nil, "Buy", [
      Beancount.posting("Assets:Stocks", Decimal.new("10"), "AAPL",
        price: %{amount: Decimal.new("15"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("-150"), "USD")
    ]),
    Beancount.transaction(~D[2020-01-04], "txn", nil, "Sell", [
      Beancount.posting("Assets:Stocks", Decimal.new("-15"), "AAPL",
        cost: lot,
        price: %{amount: Decimal.new("30"), currency: "USD", type: :unit}
      ),
      Beancount.posting("Assets:Cash", Decimal.new("450"), "USD")
    ])
  ]
  """
}

root = Path.join([File.cwd!(), "test", "fixtures", "golden"])

for {name, body} <- cases do
  dir = Path.join(root, name)
  File.mkdir_p!(dir)
  path = Path.join(dir, "input.exs")
  File.write!(path, String.trim(body) <> "\n")
  IO.puts("wrote #{path}")
end
