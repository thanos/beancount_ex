defmodule Beancount.TestFixtures do
  @moduledoc false

  @doc "Canonical salary ledger used across report and compare tests."
  @spec salary_ledger() :: [Beancount.Directive.t()]
  def salary_ledger do
    [
      Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
      Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
      Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
        Beancount.posting("Assets:Bank", Decimal.new("5000"), "USD"),
        Beancount.posting("Income:Salary", Decimal.new("-5000"), "USD")
      ])
    ]
  end

  @doc "Salary ledger with Equity:Opening (storage and queries tests)."
  @spec salary_ledger_with_equity() :: [Beancount.Directive.t()]
  def salary_ledger_with_equity do
    [
      Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
      Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
      Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
      Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
        Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
        Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
      ])
    ]
  end

  @doc "Ledger used by queries tests (opens + two transactions)."
  @spec queries_ledger() :: [Beancount.Directive.t()]
  def queries_ledger do
    [
      Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
      Beancount.open(~D[2026-01-01], "Assets:Cash", ["USD"]),
      Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
      Beancount.transaction(~D[2026-01-15], "*", "Employer", "Salary", [
        Beancount.posting("Assets:Bank", Decimal.new("100"), "USD"),
        Beancount.posting("Income:Salary", Decimal.new("-100"), "USD")
      ]),
      Beancount.transaction(~D[2026-02-15], "*", nil, "ATM", [
        Beancount.posting("Assets:Cash", Decimal.new("50"), "USD"),
        Beancount.posting("Assets:Bank", Decimal.new("-50"), "USD")
      ])
    ]
  end
end
