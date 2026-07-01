# Compile-once vs re-process query paths on example.beancount.
#
# Run: mix run bench/compiler_bench.exs

example = File.read!("test/fixtures/external/beancount/example.beancount")
{:ok, directives} = Beancount.parse_text(example)

bql = "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account"

compiled = Beancount.Engine.Elixir.CompiledLedger.compile(directives)
{:ok, query} = Beancount.BQL.parse(bql)

inputs = %{
  "compile once" => fn -> Beancount.Engine.Elixir.CompiledLedger.compile(directives) end,
  "query compiled" => fn ->
    {:ok, _} = Beancount.Engine.Elixir.CompiledLedger.query(compiled, query)
  end,
  "re-process per query" => fn ->
    {:ok, _} = Beancount.Engine.Elixir.query(example, bql)
  end
}

Benchee.run(inputs, time: 1, warmup: 0)
Beancount.Engine.Elixir.CompiledLedger.close(compiled)
