# Oracle Strategy

`beancount_ex` is the **behavioral oracle** for native Elixir General Ledger
implementations. It wraps real Beancount behind a stable Elixir API; native
engines validate against it.

## What is an oracle?

In testing, an *oracle* is a trusted reference that tells you what the correct
answer should be. Beancount is a mature, widely used, double-entry accounting
engine. By wrapping it behind a stable Elixir API, we get a reference
implementation whose behavior a native engine can be compared against.

## Why Beancount?

- It is **correct and battle-tested** across years of real-world ledgers.
- It has a **well-defined text format** that we can render deterministically.
- It exposes a **checker** (`bean-check`) we can drive programmatically.

Rather than re-deriving accounting semantics from scratch, a native engine
can be validated against Beancount's observable behavior.

## The plan

```
beancount_ex v1.0  =  Beancount in Elixir (stable oracle)
                      - Directive structs, renderer, parser
                      - Engine.CLI (shells out to bean-check / bean-query)
                      - Golden files, property generators
                      - Beancount.Engine behaviour (the seam)

beancount_gl  v0.1  =  Native Elixir General Ledger (implements the behaviour)
                      - Inventory booking (FIFO, LIFO, STRICT, AVERAGE, NONE)
                      - Balance assertions, pad resolution, tolerance
                      - Datalog query engine (via ex_datalog)
                      - Oracle comparison against beancount_ex
```

At every step the public `Beancount.*` API stays identical. Applications built
on `beancount_ex` keep working unchanged when the engine is swapped to
`beancount_gl`.

## How equivalence is checked

1. Generate valid ledgers with `Beancount.Property` (StreamData).
2. Run the same input through the oracle (`Beancount.Engine.CLI`) and the
   candidate native engine (`BeancountGl.Engine.Elixir`).
3. Compare the normalized results from `check/1` and canned report queries
   via `BeancountGl.Compare.compare/3`.

```elixir
{:ok, :equivalent} =
  BeancountGl.Compare.compare(Beancount.Engine.CLI, BeancountGl.Engine.Elixir, ledger)
```

On mismatch, `BeancountGl.Diff` describes which callback diverged and the
normalized oracle vs native payloads.

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
