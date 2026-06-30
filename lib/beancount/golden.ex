defmodule Beancount.Golden do
  @moduledoc """
  Helpers for golden-file regression testing.

  A golden fixture is a directory under `test/fixtures/golden/` containing:

    * `input.exs` - an Elixir script whose last expression is a directive list.
    * `expected.bean` - the expected rendered Beancount text.
    * `expected.result.json` - the expected normalized `Beancount.Result`
      (only meaningful when real Beancount is available).

  Rendering is deterministic, so the rendered output of `input.exs` must match
  `expected.bean` byte-for-byte. The `mix beancount.golden.update` task
  regenerates these files.
  """

  @doc """
  Root directory containing all golden fixtures.
  """
  @spec root() :: Path.t()
  def root, do: Path.join([File.cwd!(), "test", "fixtures", "golden"])

  @doc """
  List all golden fixture case directories.
  """
  @spec cases() :: [Path.t()]
  def cases do
    case File.ls(root()) do
      {:ok, entries} ->
        entries
        |> Enum.map(&Path.join(root(), &1))
        |> Enum.filter(&File.dir?/1)
        |> Enum.sort()

      {:error, _reason} ->
        []
    end
  end

  @doc """
  Evaluate a fixture's `input.exs` and return its directive list.
  """
  @spec load_directives(Path.t()) :: [Beancount.Directive.t()]
  def load_directives(case_dir) do
    {directives, _binding} = Code.eval_file(input_path(case_dir))
    directives
  end

  @doc """
  Render a fixture's directives to `.bean` text.
  """
  @spec render(Path.t()) :: binary()
  def render(case_dir) do
    case_dir |> load_directives() |> Beancount.render()
  end

  @doc """
  Read a fixture's expected `.bean` text, or `nil` if it does not exist.
  """
  @spec expected_bean(Path.t()) :: binary() | nil
  def expected_bean(case_dir), do: read(bean_path(case_dir))

  @doc """
  Read and decode a fixture's expected normalized result, or `nil`.
  """
  @spec expected_result(Path.t()) :: map() | nil
  def expected_result(case_dir) do
    case read(result_path(case_dir)) do
      nil -> nil
      json -> Jason.decode!(json)
    end
  end

  @doc false
  @spec input_path(Path.t()) :: Path.t()
  def input_path(case_dir), do: Path.join(case_dir, "input.exs")

  @doc false
  @spec bean_path(Path.t()) :: Path.t()
  def bean_path(case_dir), do: Path.join(case_dir, "expected.bean")

  @doc false
  @spec result_path(Path.t()) :: Path.t()
  def result_path(case_dir), do: Path.join(case_dir, "expected.result.json")

  defp read(path) do
    case File.read(path) do
      {:ok, contents} -> contents
      {:error, _reason} -> nil
    end
  end
end
