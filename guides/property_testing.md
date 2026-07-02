# Property Testing

`beancount_ex` ships generative-testing infrastructure built on
[StreamData](https://hexdocs.pm/stream_data). The generators live in
`Beancount.Property` (compiled only in the `:test` and `:dev` environments).

## Generators

- `account/0` - valid account names such as `Assets:Bank`.
- `currency/0` - commodity codes.
- `date/0` - `Date` values within a bounded range.
- `amount/0` - positive `Decimal` amounts.
- `metadata/0` - small metadata maps.
- `balanced_transaction/0` - transactions whose postings always sum to zero.
- `ledger/0` - a complete, valid ledger: `open` directives for every account
  used, followed by a balanced transaction.

## Properties

```elixir
use ExUnitProperties

property "balanced transactions always render" do
  check all txn <- Beancount.Property.balanced_transaction() do
    assert is_binary(Beancount.render([txn]))
  end
end

property "rendering is deterministic" do
  check all ledger <- Beancount.Property.ledger() do
    assert Beancount.render(ledger) == Beancount.render(ledger)
  end
end
```

The suite verifies the core invariants:

- **balanced transactions always render** to a binary,
- **rendering is deterministic**,
- **generated ledgers declare an `open` for every account used**, and
- (integration, tagged `:beancount`) **generated ledgers pass `bean-check`**.

For oracle comparison (validating a native engine against the CLI), see
[Oracle Strategy](oracle_strategy.md) and the separate `beancount_gl` package.
