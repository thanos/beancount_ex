# Parsing

> **Accounting track:** to use the parser in an application, see
> [Accounting: Getting started](accounting/getting_started.md) and
> [Parsing (Livebook)](livebook/parsing.livemd). This page documents the
> library implementation.

v0.3 adds `Beancount.Parser`, a native NimbleParsec-based parser that turns
`.bean` text into the same typed directive structs you build with the public
`Beancount.*` constructors.

## Public API

```elixir
# Parse text
{:ok, directives} = Beancount.parse_text(bean_text)

# Parse a file
{:ok, directives} = Beancount.parse_file("ledger.bean")

# Lists pass through unchanged
{:ok, directives} = Beancount.parse(directives)

# Raise on failure
directives = Beancount.parse!(bean_text)
```

Parse failures return `{:error, %Beancount.Parser.Error{}}` with `line`,
`column`, `message`, and optional `token` fields - never a bare
`FunctionClauseError`.

## Grammar coverage

The parser covers the full Beancount surface syntax used in production ledgers:

- dated directives: `open`, `close`, `commodity`, `balance`, `price`, `event`,
  `note`, `document`, `pad`, `query`, `custom`
- undated directives: `include`, `option`, `plugin`, `pushtag`, `poptag`
- transactions with flags, payee, narration, tags, links, metadata, and postings
  (amount elision, cost specs `{…}`, and price annotations `@` / `@@`)
- comments (`;`), metadata (`key: value`), and multi-line metadata blocks

New directive structs (`Query`, `Plugin`, `PushTag`, `PopTag`) implement the
`Beancount.Directive` protocol so they round-trip through `Beancount.render/1`.

## Round-trip contract

For every golden fixture:

```elixir
expected = File.read!("expected.bean")
{:ok, directives} = Beancount.parse_text(expected)
assert Beancount.render(directives) == expected
```

Property tests also assert `parse(render(ledger))` recovers equivalent text for
generated ledgers from `Beancount.Property.ledger/0`.

## Relationship to engines

`Beancount.Engine.Elixir` uses the parser internally for `check/1` and `query/2`.
`Beancount.Engine.CLI` continues to shell out to `bean-check` / `bean-query` and
remains the default engine until native parity is proven.

Parsing is independent of validation semantics: the parser produces structs;
engines decide what is valid.
