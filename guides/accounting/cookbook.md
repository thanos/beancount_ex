# Accounting cookbook

Practical recipes for common financial events, using `beancount_ex`. Mirrors the
structure of the upstream
[Command-line Accounting Cookbook](https://beancount.github.io/docs/command_line_accounting_cookbook/).

Each section shows Elixir constructors; rendered `.bean` output is what
`Beancount.check/1` validates.

## Account naming

Use colon-separated hierarchies. A common pattern for assets and liabilities:

```
Type : Country : Institution : Account
```

```elixir
[
  Beancount.open(~D[2020-01-01], "Assets:US:BofA:Checking", ["USD"]),
  Beancount.open(~D[2020-01-01], "Liabilities:US:Amex:Platinum", ["USD"]),
  Beancount.open(~D[2020-01-01], "Expenses:Food:Restaurant", ["USD"]),
  Beancount.open(~D[2020-01-01], "Equity:Opening", ["USD"])
]
```

Open accounts as you need them; you do not need a full chart up front.

### Choosing an account type

| If amounts matter for a **period** | Use `Income` or `Expenses` |
| If amounts are a **running balance** | Use `Assets` or `Liabilities` |
| Generally positive from your view | `Assets` or `Expenses` |
| Generally negative from your view | `Liabilities` or `Income` |

## Cash

Define a wallet account and optionally foreign cash:

```elixir
opens = [
  Beancount.open(~D[1973-04-27], "Assets:Cash", ["USD"]),
  Beancount.open(~D[1973-04-27], "Assets:ForeignCash", ["USD"])
]
```

### ATM withdrawal

```elixir
Beancount.transaction(~D[2026-06-28], "*", "ATM", "Withdrawal", [
  Beancount.posting("Assets:US:BofA:Checking", Decimal.new("-700.00"), "USD"),
  Beancount.posting("Assets:Cash", nil, nil)
])
```

### Cash distribution between balance assertions

When you count physical cash and allocate untracked spending:

```elixir
[
  Beancount.balance(~D[2026-05-12], "Assets:Cash", Decimal.new("234.13"), "USD"),
  Beancount.transaction(~D[2026-06-19], "*", nil, "Cash distribution", [
    Beancount.posting("Expenses:Food:Restaurant", Decimal.new("402.30"), "USD"),
    Beancount.posting("Expenses:Food:Alcohol", Decimal.new("100.00"), "USD"),
    Beancount.posting("Assets:Cash", nil, nil)
  ]),
  Beancount.balance(~D[2026-06-20], "Assets:Cash", Decimal.new("194.34"), "USD")
]
```

## Salary income

Track employer metadata with an event, then open income and tax accounts:

```elixir
employer_setup = [
  Beancount.event(~D[2012-12-13], "employer", "Acme Inc."),
  Beancount.open(~D[2012-12-13], "Income:US:Acme:Salary", ["USD"]),
  Beancount.open(~D[2012-12-13], "Assets:US:BofA:Checking", ["USD"]),
  Beancount.open(~D[2014-01-01], "Expenses:Taxes:TY2014:US:Federal", ["USD"]),
  Beancount.open(~D[2014-01-01], "Expenses:Taxes:TY2014:US:SocSec", ["USD"])
]
```

### Pay stub deposit

Mirror each pay-stub line as a posting. A simplified deposit:

```elixir
Beancount.transaction(~D[2026-02-28], "*", "ACME INC", "PAYROLL", [
  Beancount.posting("Assets:US:BofA:Checking", Decimal.new("3364.67"), "USD"),
  Beancount.posting("Income:US:Acme:Salary", Decimal.new("-5384.62"), "USD"),
  Beancount.posting("Expenses:Taxes:TY2014:US:Federal", Decimal.new("1200.00"), "USD"),
  Beancount.posting("Expenses:Taxes:TY2014:US:SocSec", Decimal.new("819.95"), "USD")
])
```

Use `Beancount.income_statement/1` at year end to reconcile against your W-2.

## Investing and trading

Open a brokerage with FIFO booking (or `STRICT`, `LIFO`, `AVERAGE`):

```elixir
Beancount.open(~D[2020-01-01], "Assets:US:ETrade:AAPL", ["AAPL"], booking: "FIFO")
```

### Buy shares with cost basis

```elixir
Beancount.transaction(~D[2026-01-15], "*", "ETRADE", "Buy AAPL", [
  Beancount.posting("Assets:US:ETrade:AAPL", Decimal.new("10"), "AAPL",
    cost: %{amount: Decimal.new("150"), currency: "USD"}
  ),
  Beancount.posting("Assets:US:ETrade:Cash", Decimal.new("-1500"), "USD")
])
```

### Sell with unit price

```elixir
Beancount.transaction(~D[2026-06-01], "*", "ETRADE", "Sell AAPL", [
  Beancount.posting("Assets:US:ETrade:AAPL", Decimal.new("-10"), "AAPL",
    price: %{amount: Decimal.new("180"), currency: "USD", type: :unit}
  ),
  Beancount.posting("Assets:US:ETrade:Cash", Decimal.new("1800"), "USD")
])
```

### Dividend

```elixir
Beancount.transaction(~D[2026-03-15], "*", "ETRADE", "AAPL dividend", [
  Beancount.posting("Assets:US:ETrade:Cash", Decimal.new("42.50"), "USD"),
  Beancount.posting("Income:US:ETrade:Dividends", Decimal.new("-42.50"), "USD")
])
```

Use `Beancount.holdings/1` for units and cost columns per asset account.

## Currency transfer

Moving USD between your own accounts:

```elixir
Beancount.transaction(~D[2026-04-01], "*", nil, "Transfer to savings", [
  Beancount.posting("Assets:US:BofA:Savings", Decimal.new("1000"), "USD"),
  Beancount.posting("Assets:US:BofA:Checking", Decimal.new("-1000"), "USD")
])
```

## Balance assertions and pad

Assert an account balance at a date; use `pad` to auto-fill from equity when
reconciling:

```elixir
[
  Beancount.open(~D[2026-01-01], "Assets:Cash", ["USD"]),
  Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
  Beancount.pad(~D[2026-01-02], "Assets:Cash", "Equity:Opening"),
  Beancount.balance(~D[2026-01-03], "Assets:Cash", Decimal.new("100"), "USD")
]
```

## Options

Set operating currency and tolerance defaults at the top of a ledger:

```elixir
[
  Beancount.option("operating_currency", "USD"),
  Beancount.option("title", "My Ledger")
  | rest_of_ledger
]
```

## Putting it together

```elixir
ledger =
  employer_setup ++
    opens ++
    [
      Beancount.transaction(~D[2026-02-28], "*", "ACME INC", "PAYROLL", [...]),
      Beancount.transaction(~D[2026-03-01], "*", "Landlord", "Rent", [...])
    ]

{:ok, _} = Beancount.check(ledger)
{:ok, income} = Beancount.income_statement(ledger)
```

## Next

- [Running reports](running_reports.md) - present results in a UI
- [In context](in_context.md) - architectural overview
