# Engines

All execution in `beancount_ex` flows through the `Beancount.Engine` behaviour.
This is the seam that lets the backend change without breaking the public API.

```elixir
defmodule Beancount.Engine do
  @callback render(term()) :: binary()
  @callback check(binary()) ::
              {:ok, Beancount.Result.t()} | {:error, Beancount.Result.t()}
end
```

## Selecting an engine

```elixir
config :beancount_ex, engine: Beancount.Engine.CLI
```

`Beancount.render/1` and `Beancount.check/1` dispatch to
`Beancount.Engine.configured/0`, so applications never call an engine directly.

## The CLI engine (v0.1)

`Beancount.Engine.CLI` is the initial engine. It:

- delegates `render/1` to `Beancount.Renderer`, and
- delegates `check/1` to `Beancount.Checker`, which shells out to `bean-check`.

The `bean-check` binary is configurable:

```elixir
config :beancount_ex, bean_check_path: "bean-check"
```

If the binary cannot be found, `Beancount.Checker` raises
`Beancount.Checker.NotInstalledError`. This is deliberately distinct from a
ledger that *fails* validation (which returns `{:error, %Beancount.Result{}}`)
so that environment problems are never confused with accounting errors.

## Results are engine-independent

Every engine populates the same `Beancount.Result` struct, and
`Beancount.Normalizer` produces a stable, backend-independent view of the
output. This normalization is what makes cross-engine comparison possible.

## Future engines

The roadmap includes native engines that implement the same behaviour:

```
Beancount.Engine.Elixir   # native Elixir
Beancount.Engine.Rust     # native Rust (NIF/port)
```

Because they share the behaviour and the `Beancount.Result` shape, swapping
engines requires **no changes** to `Beancount.*` callers.
