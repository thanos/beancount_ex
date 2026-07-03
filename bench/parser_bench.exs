# Parser throughput on golden fixtures and example.beancount.
#
# Run: mix run bench/parser_bench.exs

golden_sources =
  "test/fixtures/golden"
  |> Path.join("*/expected.bean")
  |> Path.wildcard()
  |> Enum.map(&File.read!/1)

example = "test/fixtures/external/beancount/example.beancount"

inputs = %{
  "golden fixtures (30)" => fn -> Enum.each(golden_sources, &Beancount.parse_text/1) end,
  "example.beancount" => fn -> Beancount.parse_text(File.read!(example)) end
}

Benchee.run(inputs, time: 3, warmup: 1)
