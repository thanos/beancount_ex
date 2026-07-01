Mix.install([{:benchee, "~> 1.3"}])

golden_beans =
  "test/fixtures/golden"
  |> Path.join("*/expected.bean")
  |> Path.wildcard()

example = "test/fixtures/external/beancount/example.beancount"

inputs = %{
  "golden fixtures (29)" => fn -> Enum.each(golden_beans, &Beancount.parse_text/1) end,
  "example.beancount" => fn -> Beancount.parse_text(File.read!(example)) end
}

Benchee.run(inputs, time: 3, warmup: 1)
