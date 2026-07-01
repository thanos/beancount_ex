# Native BQL query engine

v0.5 adds `Beancount.BQL`, a parser and evaluator for the Beancount Query
Language (BQL). `Engine.Elixir.query/2` parses arbitrary BQL strings and
evaluates them against a compiled fact base instead of matching a hardcoded map.

## Public API

```elixir
{:ok, query} = Beancount.BQL.parse(bql_string)
compiled = Beancount.Engine.Elixir.CompiledLedger.compile(directives)
{:ok, result} = Beancount.BQL.evaluate(query, compiled)
```

`Beancount.Report` and `Beancount.Compare` canned queries use the same path.

## Supported grammar

| Construct | Example |
|-----------|---------|
| `SELECT` | `SELECT account, sum(position) AS balance` |
| `WHERE` | `WHERE account ~ "^Assets"` or `account = "Assets:Bank"` |
| `GROUP BY` | `GROUP BY account` |
| `ORDER BY` | `ORDER BY account, date` |
| Aggregations | `sum(position)`, `units(...)`, `cost(...)` |

Journal queries:

```sql
SELECT date, flag, payee, narration, position, balance
WHERE account = "Assets:Bank" ORDER BY date
```

Unsupported constructs return `{:error, {:unsupported_bql, _}}` from the native
engine (use `Engine.CLI` and `bean-query` as the oracle for broader coverage).

## Performance

Compile once with `CompiledLedger.compile/1`, then run many queries. For ledgers
with more than 1,000 directives, postings are indexed in ETS for faster scans.
Call `CompiledLedger.close/1` to release ETS tables.

See `guides/directive_compiler.md` and `guides/performance.md`.
