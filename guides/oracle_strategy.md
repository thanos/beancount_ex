# Oracle Strategy

`beancount_ex` is the **behavioral oracle** for the native Elixir engine.
It wraps real Beancount behind a stable Elixir API; the native engine
validates against it.

## What is an oracle?

In testing, an *oracle* is a trusted reference that tells you what the correct
answer should be. Beancount is a mature, widely used, double-entry accounting
engine. By wrapping it behind a stable Elixir API, we get a reference
implementation whose behavior the native engine can be compared against.

## Why Beancount?

- It is **correct and battle-tested** across years of real-world ledgers.
- It has a **well-defined text format** that we can render deterministically.
- It exposes a **checker** (`bean-check`) we can drive programmatically.

Rather than re-deriving accounting semantics from scratch, the native engine
can be validated against Beancount's observable behavior.

## The plan

```
v0.6  beancount_ex  =  Ecto storage + native engine + canned reports
                     - SQLite (:memory:) and file backends
                     - Booking, balance assertions, pad resolution
                     - Ecto.Query for ad-hoc queries
                     - Golden fixture parity via Compare.compare/3

v0.7  beancount_ex  =  BQL gap closure + Postgres/Mnesia backends
                     - Full BQL surface (functions, filters, JOINs)
                     - Storage backends: PostgreSQL (Ecto), Mnesia
                     - Plugin semantics, price database

v1.0  beancount_ex  =  Stable oracle + optional split
                     - Engine behaviour as the stable seam
                     - Optional extraction of native engine to separate package
```

At every step the public `Beancount.*` API stays identical.

## How equivalence is checked

1. Generate valid ledgers with `Beancount.Property` (StreamData).
2. Run the same input through the oracle (`Engine.CLI`) and the native
   engine (`Engine.Elixir`).
3. Compare the normalized results from `check/1` and canned report queries
   via `Beancount.Compare.compare/3`.

```elixir
{:ok, :equivalent} =
  Beancount.Compare.compare(Beancount.Engine.CLI, Beancount.Engine.Elixir, ledger)
```

On mismatch, `Beancount.Property.Diff` describes which callback diverged and
the normalized oracle vs native payloads.

### Parity contract

Equivalence is asserted for:

- structural `check/1` results by normalized error category
- canned reports: `balances`, `balance_sheet`, `income_statement`, `holdings`
- full booking semantics (FIFO, LIFO, STRICT, AVERAGE, NONE), balance
  assertions, pad resolution, and tolerance inference on the golden fixtures

Golden fixtures exercise booking and validation edge cases against the CLI
oracle.

Combined with golden files (deterministic, committed reference output) and
property tests (broad, generated coverage), this gives two complementary safety
nets for the native engine.

## Stability promise

The public API is intended to remain stable **forever**. New engines are an
implementation detail behind `Beancount.Engine`; they must never require a
change to `Beancount.*`.
