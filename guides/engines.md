# Engines

All execution in `beancount_ex` flows through the `Beancount.Engine` behaviour.
This is the seam that lets the backend change without breaking the public API.

```elixir
defmodule Beancount.Engine do
  @callback render(term()) :: binary()
  @callback check(binary()) ::
              {:ok, Beancount.Result.t()} | {:error, Beancount.Result.t()}
  @callback query(binary(), binary()) ::
              {:ok, Beancount.Query.Result.t()} | {:error, Beancount.Result.t()}
end
```

## Selecting an engine

```elixir
config :beancount_ex, engine: Beancount.Engine.CLI
```

`Beancount.render/1` and `Beancount.check/1` dispatch to
`Beancount.Engine.configured/0`, so applications never call an engine directly.

## The CLI engine (default)

`Beancount.Engine.CLI` is the default engine. It:

- delegates `render/1` to `Beancount.Renderer`,
- delegates `check/1` to `Beancount.Checker`, which shells out to `bean-check`, and
- delegates `query/2` to `Beancount.Query`, which shells out to `bean-query`.

The binaries are configurable:

```elixir
config :beancount_ex,
  bean_check_path: "bean-check",
  bean_query_path: "bean-query"
```

If a binary cannot be found, the relevant wrapper raises
`Beancount.Checker.NotInstalledError` / `Beancount.Query.NotInstalledError`.
This is deliberately distinct from a ledger that *fails* validation or a query
that *fails* (which return `{:error, %Beancount.Result{}}`) so that environment
problems are never confused with accounting errors.

## Results are engine-independent

Every engine populates the same `Beancount.Result` and `Beancount.Query.Result`
structs, and `Beancount.Normalizer` produces a stable, backend-independent view
of the output. This normalization is what makes cross-engine comparison
possible.

Because `query/2` is part of the behaviour, native engines must implement it
too - keeping the oracle contract uniform across backends.

## The Elixir engine (v0.5)

`Beancount.Engine.Elixir` is a native engine with **golden parity** against the
CLI oracle for check and supported BQL queries:

```elixir
config :beancount_ex, engine: Beancount.Engine.Elixir
```

| Callback | v0.5 behaviour |
|----------|----------------|
| `render/1` | delegates to `Beancount.Renderer` |
| `check/1` | booking, balance assertions, pad resolution, tolerance inference |
| `query/2` | native BQL via `Beancount.BQL` and `CompiledLedger` |

Supported BQL includes balances, balance sheet, income statement, holdings,
journal queries, and `WHERE` / `GROUP BY` / `ORDER BY` with `sum(position)`,
`units()`, and `cost()`. See `guides/query_engine.md`.

For BQL constructs not yet implemented natively, use `Engine.CLI` (`bean-query`)
as the oracle.

See `guides/booking.md`, `guides/directive_compiler.md`, and
`guides/reconciliation.md`.

`Beancount.check_file/1` routes through the configured engine. The CLI engine
passes the file path to `bean-check` (so `include` resolves relative to the
file). With `Beancount.Engine.Elixir` configured, the file is read into text
before `check/1` runs, so `include` directives are not resolved relative to
the original path.

## Future engines

The roadmap also includes:

```
Beancount.Engine.Rust     # native Rust (NIF/port)
```

Because they share the behaviour and the `Beancount.Result` shape, swapping
engines requires **no changes** to `Beancount.*` callers.
