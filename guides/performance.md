# Performance

Run benchmarks locally (not part of CI):

```bash
mix run bench/parser_bench.exs
mix run bench/engine_bench.exs
mix run bench/compiler_bench.exs
mix run bench/query_bench.exs
mix run bench/datalog_bench.exs
```

`Engine.Elixir` compiles directives once via `CompiledLedger` and evaluates BQL
natively. For ledgers over 1,000 directives, postings are indexed in ETS.

Use `Engine.CLI` when you need full `bean-query` coverage beyond the native BQL
subset documented in `guides/query_engine.md`.
