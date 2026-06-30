# Oracle Strategy

The long-term purpose of `beancount_ex` is to be a **behavioral oracle** for a
future native Elixir General Ledger.

## What is an oracle?

In testing, an *oracle* is a trusted reference that tells you what the correct
answer should be. Beancount is a mature, widely used, double-entry accounting
engine. By wrapping it behind a stable Elixir API, we get a reference
implementation whose behavior we can compare against.

## Why Beancount?

- It is **correct and battle-tested** across years of real-world ledgers.
- It has a **well-defined text format** that we can render deterministically.
- It exposes a **checker** (`bean-check`) we can drive programmatically.

Rather than re-deriving accounting semantics from scratch, the native engine
can be validated against Beancount's observable behavior.

## The plan

```
v0.1  Beancount  ->  Engine.CLI     ->  Real Beancount      (v0.1)
v0.3  Beancount  ->  Engine.Elixir                          (native)
v0.4  Beancount  ->  Engine.Rust                            (native, fast)
```

At every step the public `Beancount.*` API stays identical. Applications built
on v0.1 keep working unchanged when the engine is swapped.

## How equivalence is checked

1. Generate valid ledgers with `Beancount.Property` (StreamData).
2. Run the same input through the oracle (`Engine.CLI`) and the candidate
   native engine (`Engine.Elixir`).
3. Compare the **normalized** results from `check/1` and the canned report
   queries via `Beancount.Compare.compare/3` (also exposed as
   `Beancount.Property.compare/3` in test/dev).

```elixir
{:ok, :equivalent} =
  Beancount.Compare.compare(Beancount.Engine.CLI, Beancount.Engine.Elixir, ledger)
```

On mismatch, `Beancount.Property.Diff` describes which callback diverged and
the normalized oracle vs native payloads.

### v0.3 parity contract

Equivalence is asserted for:

- structural `check/1` results on simple ledgers (opens, closes, syntactic balance)
- canned reports: `balances`, `balance_sheet`, `income_statement`, `holdings`

Full booking semantics (FIFO/LIFO, cost-basis reduction, balance assertions,
pad resolution) are **excluded** until v0.4. Golden fixtures that exercise
booking are still validated against the CLI oracle; they are not part of the
native compare contract.

Combined with golden files (deterministic, committed reference output) and
property tests (broad, generated coverage), this gives two complementary safety
nets for the native engine.

## Stability promise

The public API is intended to remain stable **forever**. New engines are an
implementation detail behind `Beancount.Engine`; they must never require a
change to `Beancount.*`.
