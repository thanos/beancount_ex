# Fact base scan and filter timings.
#
# Run: mix run bench/datalog_bench.exs

alias Beancount.Engine.Elixir.{CompiledLedger, FactBase, Index}

directives =
  for index <- 1..2_000,
      do: Beancount.open(~D[2026-01-01], "Assets:Bench#{index}", ["USD"])

compiled = CompiledLedger.compile(directives)
fact_base = compiled.fact_base
index = compiled.index

{scan_us, postings} =
  :timer.tc(fn ->
    Enum.filter(fact_base.postings, &String.starts_with?(&1.account, "Assets:Bench1"))
  end)

{indexed_us, _} =
  :timer.tc(fn ->
    Index.postings_for_account(index, fact_base, "Assets:Bench100")
  end)

IO.puts("postings=#{length(postings)} scan_us=#{scan_us} indexed_us=#{indexed_us}")
CompiledLedger.close(compiled)
