defmodule Mix.Tasks.Beancount.Golden.Update do
  @shortdoc "Regenerate golden fixture files from their input.exs"

  @moduledoc """
  Regenerate the golden fixtures under `test/fixtures/golden/`.

  For every fixture case it:

    * evaluates `input.exs` and writes the rendered `expected.bean`;
    * if `bean-check` is available, runs it and writes the normalized
      `expected.result.json`.

  ## Usage

      mix beancount.golden.update

  Rendering is deterministic, so re-running the task without changing inputs
  produces no diff.
  """

  use Mix.Task

  alias Beancount.{Checker, Golden}

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.config")

    cases = Golden.cases()

    if cases == [] do
      Mix.shell().info("No golden fixtures found under #{Golden.root()}")
    else
      Enum.each(cases, &update_case/1)
    end
  end

  defp update_case(case_dir) do
    name = Path.basename(case_dir)
    bean = Golden.render(case_dir)
    File.write!(Golden.bean_path(case_dir), bean)
    Mix.shell().info("updated #{name}/expected.bean")

    if Checker.available?() do
      update_result(case_dir, name, bean)
    else
      Mix.shell().info("skipped #{name}/expected.result.json (bean-check not available)")
    end
  end

  defp update_result(case_dir, name, bean) do
    {_status, result} = Beancount.check_text(bean)
    json = Jason.encode!(result.normalized, pretty: true)
    File.write!(Golden.result_path(case_dir), json <> "\n")
    Mix.shell().info("updated #{name}/expected.result.json")
  end
end
