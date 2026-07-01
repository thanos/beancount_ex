# Native BQL evaluation vs compile-once pattern.
#
# Run: mix run bench/query_bench.exs

alias Beancount.Engine.Elixir.CompiledLedger

ledger = [
  Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
  Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
  Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"])
]

ledger =
  ledger ++
    for index <- 1..500,
        do: [
          Beancount.open(~D[2026-01-01], "Assets:Tmp#{index}", ["USD"]),
          Beancount.transaction(~D[2026-01-31], "*", nil, "Seed #{index}", [
            Beancount.posting("Assets:Tmp#{index}", Decimal.new("1"), "USD"),
            Beancount.posting("Income:Salary", Decimal.new("-1"), "USD")
          ])
        ]
        |> List.flatten()

bql =
  "SELECT account, sum(position) AS balance WHERE account ~ \"^Assets\" GROUP BY account ORDER BY account"

{:ok, query} = Beancount.BQL.parse(bql)
compiled = CompiledLedger.compile(ledger)

{compile_us, _} = :timer.tc(fn -> CompiledLedger.compile(ledger) end)

{query_us, _} =
  :timer.tc(fn ->
    for _ <- 1..5, do: CompiledLedger.query(compiled, query)
  end)

IO.puts("compile_us=#{compile_us}")
IO.puts("five_queries_us=#{query_us}")
CompiledLedger.close(compiled)
