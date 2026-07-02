# Performance

Run benchmarks locally (not part of CI):

```bash
mix run bench/parser_bench.exs
mix run bench/engine_bench.exs
```

`Engine.Elixir` processes directives through the booking engine in memory.
The Ecto storage layer (SQLite `:memory:`) adds negligible overhead for
check/validate operations.

For large ledgers, configure SQLite with a file path to avoid in-memory
pressure:

```elixir
config :beancount_ex, Beancount.Repo, database: "ledger.db"
```

Use `Engine.CLI` when you need full `bean-query` coverage beyond the native
canned reports.
