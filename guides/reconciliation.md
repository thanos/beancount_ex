# Reconciliation harness

`test/fixtures/external/beancount/example.beancount` is vendored from upstream
(see `SOURCE`). It is test-only and not shipped in the Hex package.

`test/beancount/reconciliation_test.exs` exercises:

1. **bean-check** — the fixture is valid Beancount.
2. **parse → render → bean-query** — round-trip reports match the original.
3. **compare/3** (tagged `:reconciliation_compare`, currently skipped): full
   native engine equivalence on the 7,175-line ledger. A non-skipped test
   asserts `compare/3` returns `{:ok, :equivalent}` or a structured
   `Beancount.Property.Diff` without crashing.

Golden fixtures (30/30) gate booking parity; the example ledger is the capstone
for real-world scale.
