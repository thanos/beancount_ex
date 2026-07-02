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

## Native engines

A native Elixir General Ledger (`beancount_gl`) is available as a separate
package that implements the `Beancount.Engine` behaviour with inventory
booking, balance assertions, and native BQL queries:

```elixir
# mix.exs
{:beancount_gl, "~> 0.1"}

# config/config.exs
config :beancount_ex, engine: BeancountGl.Engine.Elixir
```

See the `beancount_gl` documentation for booking, query engine, and oracle
comparison details.

`Beancount.check_file/1` routes through the configured engine. The CLI engine
passes the file path to `bean-check` (so `include` resolves relative to the
file). External engines may handle files differently.

## Future engines

Additional engines (e.g. native Rust via NIF/port) can implement the same
behaviour. Because they share the `Beancount.Result` shape, swapping engines
requires **no changes** to `Beancount.*` callers.
