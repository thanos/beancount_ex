[
  Beancount.option("title", "Options Example"),
  Beancount.option("operating_currency", "USD"),
  Beancount.option("inferred_tolerance_default", "0.005"),
  Beancount.option("infer_tolerance_from_cost", true),
  Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"])
]
