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

## The Elixir engine (v0.3, opt-in)

`Beancount.Engine.Elixir` is a native engine with **staged parity**:

```elixir
config :beancount_ex, engine: Beancount.Engine.Elixir
```

| Callback | v0.3 behaviour |
|----------|----------------|
| `render/1` | delegates to `Beancount.Renderer` |
| `check/1` | parses text, then structural validation (opens/closes, syntactic per-currency balance) |
| `query/2` | canned reports only (`balances`, `balance_sheet`, `income_statement`, `holdings`, `journal`) |

Full inventory booking, balance-assertion evaluation, pad resolution, and
arbitrary BQL are deferred to v0.4. Unsupported BQL returns
`{:error, %Beancount.Result{}}` with a clear message.

`Beancount.check_file/1` routes through the configured engine (read file →
`check/1`).

## Future engines

The roadmap also includes:

```
Beancount.Engine.Rust     # native Rust (NIF/port)
```

Because they share the behaviour and the `Beancount.Result` shape, swapping
engines requires **no changes** to `Beancount.*` callers.
