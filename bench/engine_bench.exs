Mix.install([{:benchee, "~> 1.3"}])

golden_beans =
  "test/fixtures/golden"
  |> Path.join("*/expected.bean")
  |> Path.wildcard()

example = File.read!("test/fixtures/external/beancount/example.beancount")

inputs =
  golden_beans
  |> Enum.map(fn path -> {Path.basename(Path.dirname(path)), File.read!(path)} end)
  |> Map.new(fn {name, text} -> {"check #{name}", fn -> Beancount.Engine.Elixir.check(text) end} end)
  |> Map.put("check example.beancount", fn -> Beancount.Engine.Elixir.check(example) end)

Benchee.run(inputs, time: 2, warmup: 0)
