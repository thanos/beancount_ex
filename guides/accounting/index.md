# Accounting guides

These guides explain how to **use `beancount_ex` in a real accounting scenario**:
building ledgers, validating them, and producing reports for an application or UI.
They mirror the structure of the upstream Beancount user documentation, but every
example uses the Elixir API (`Beancount.*` constructors, `render/1`, `check/1`,
`query/2`, and canned reports).

Use this track when you are:

- building a personal finance or business accounting UI in Elixir,
- generating `.bean` files from application data,
- or prompting an LLM to construct correct double-entry transactions.

For upstream theory and philosophy, see the original Beancount docs:

- [Command-line Accounting in Context](https://beancount.github.io/docs/command_line_accounting_in_context/)
- [Command-line Accounting Cookbook](https://beancount.github.io/docs/command_line_accounting_cookbook/)

## Guides in this track

| Guide | What you learn |
|-------|----------------|
| [Getting started](getting_started.md) | Install, build a ledger, render, check |
| [In context](in_context.md) | Why double-entry bookkeeping, what reports answer, how the library fits |
| [Cookbook](cookbook.md) | Account naming, cash, salary, trading, balance assertions |
| [Running reports](running_reports.md) | Balances, income statement, journal, holdings, Explorer tables |

## Livebook notebooks

Interactive versions:

- [Getting started](../livebook/getting_started.livemd)
- [Accounting cookbook](../livebook/accounting.livemd)
- [Parsing and validation](../livebook/parsing.livemd)
- [Reporting with Explorer](../livebook/reporting.livemd)
