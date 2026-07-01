# Performance

Run benchmarks locally (not part of CI):

```bash
mix run bench/parser_bench.exs
mix run bench/engine_bench.exs
```

`Engine.Elixir` is suitable for structural validation and canned reports without
shelling out to `bean-check` / `bean-query`. For arbitrary BQL or plugin-heavy
ledgers, prefer `Engine.CLI` until native coverage expands.
