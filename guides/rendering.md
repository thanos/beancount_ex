# Rendering

`Beancount.Renderer` turns a stream of directive structs into valid Beancount
text. Rendering is pure and **deterministic**: rendering the same stream twice
produces byte-identical output. This is the foundation of golden-file testing
and of using Beancount as an oracle.

## The directive protocol

Every directive struct implements the `Beancount.Directive` protocol, which
defines a single function:

```elixir
@spec to_bean(t()) :: iodata()
```

`Beancount.Renderer.render/1` calls `to_bean/1` on each directive and joins the
fragments with a blank line, terminating the document with a single newline.

```elixir
iex> Beancount.render([Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"])])
"2026-01-01 open Assets:Bank USD\n"
```

## What is supported

- **dates** — rendered as ISO-8601 `YYYY-MM-DD`.
- **flags** — transaction flags (`*`, `!`) and per-posting flags.
- **postings** — amounts right-aligned for readability.
- **metadata** — `key: value` lines, emitted in sorted order for determinism.
- **tags & links** — `#tag` and `^link` suffixes, sorted.
- **commodities** — currency codes on postings, balances and prices.
- **quoted strings** — payees, narrations, notes, documents, events, and
  string metadata, with `"` and `\` escaped.
- **cost & price annotations** — `{10.00 USD}` cost basis and `@`/`@@` prices.

## Posting alignment

Within a transaction, amounts are right-aligned so decimal values line up:

```beancount
2026-01-31 * "Employer" "Salary"
  Assets:Bank     5000 USD
  Income:Salary  -5000 USD
```

Alignment is computed per transaction and is fully deterministic.

## Determinism guarantees

- Metadata keys are sorted.
- Tags and links are sorted.
- Decimals are rendered in plain (non-scientific) notation.

These rules mean output never depends on map ordering or runtime state, so it
is safe to commit rendered output as golden fixtures.
