# Booking engine

`Beancount.Engine.Elixir` implements native inventory booking for the native engine:

- **FIFO / LIFO / NONE**: consume lots oldest-first, newest-first, or allow shorts.
- **STRICT**: reductions with explicit cost specs must match exactly one lot.
- **AVERAGE**: merge lots before reduction.

Lots are tracked per account and currency in the engine's internal inventory
layer. Reductions are applied by the engine's booking layer.

`Beancount.Compare.compare/3` validates oracle parity on the 30 golden fixtures:
check results are compared by normalized error category; canned reports
(`balances`, `balance_sheet`, `income_statement`, `holdings`) must match after
position-string normalization.
