# Golden Files

Golden-file testing pins the rendered (and, optionally, checked) output of a
ledger so that any unintended change is caught as a regression.

## Layout

Fixtures live under `test/fixtures/golden/`. Each case is a directory:

```
test/fixtures/golden/
  salary/
    input.exs              # Elixir script whose last expression is a directive list
    expected.bean          # expected rendered Beancount text
    expected.result.json   # expected normalized result (requires bean-check)
```

### `input.exs`

```elixir
[
  Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
  Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
  Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
    Beancount.posting("Assets:Bank", Decimal.new("5000"), "USD"),
    Beancount.posting("Income:Salary", Decimal.new("-5000"), "USD")
  ])
]
```

## How the tests work

`Beancount.GoldenTest` iterates every case from `Beancount.Golden.cases/0` and
asserts that rendering `input.exs` equals `expected.bean`. Because rendering is
deterministic, this needs **no** Beancount installation and runs as part of the
default `mix test`.

The `expected.result.json` comparison lives in `Beancount.IntegrationTest` and
is tagged `:beancount`, so it only runs when you opt in.

## Regenerating

```bash
mix beancount.golden.update
```

The task regenerates every `expected.bean` from its `input.exs`. When
`bean-check` is available it also regenerates `expected.result.json`; otherwise
that step is skipped. Re-running with unchanged inputs produces no diff.

## Adding a case

1. Create `test/fixtures/golden/<name>/input.exs`.
2. Run `mix beancount.golden.update`.
3. Review and commit the generated files.
