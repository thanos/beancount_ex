# Directive compiler

The directive compiler processes a ledger once and materializes a queryable fact
base. Repeated BQL queries reuse the compiled state instead of re-running booking,
pad resolution, and balance evaluation.

## Layers

1. **Logical fact base** - accounts, postings, inventory lots, and options as
   plain Elixir data (`FactBase` module).
2. **ETS indexes** - optional posting indexes for ledgers larger than 1,000
   directives (`Index` module).
3. **Compiled interface** (`CompiledLedger`) - compile and query entry point.

## Usage

```elixir
directives = Beancount.parse!(text)
compiled = Beancount.Engine.Elixir.CompiledLedger.compile(directives)

{:ok, balances} =
  compiled
  |> then(&Beancount.BQL.parse("SELECT account, sum(position) AS balance GROUP BY account"))
  |> then(fn {:ok, q} -> Beancount.Engine.Elixir.CompiledLedger.query(compiled, q) end)

Beancount.Engine.Elixir.CompiledLedger.close(compiled)
```

`Engine.Elixir.query/2` compiles internally for each call. For multiple queries
on the same ledger, hold a `CompiledLedger` and call `query/2` repeatedly.

## Fact relations

| Relation | Contents |
|----------|----------|
| `opens` | Open directives by account |
| `inventory` | Post-booking lot inventory |
| `postings` | Flattened transaction postings |
| `lots` | Holdings snapshot per account |

The BQL evaluator (`QueryEngine`) projects and filters these relations to
produce `Beancount.Query.Result` rows.
