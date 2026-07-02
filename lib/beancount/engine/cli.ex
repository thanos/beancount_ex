defmodule Beancount.Engine.CLI do
  @moduledoc """
  The default engine: a thin wrapper around the Beancount `bean-check` and
  `bean-query` CLI tools.

  This is the behavioral oracle. Rendering is delegated to
  `Beancount.Renderer`, checking to `Beancount.Checker` (shells out to
  `bean-check`), and queries to `Beancount.Query` (shells out to `bean-query`).

  The native `Beancount.Engine.Elixir` implements the same
  `Beancount.Engine` behaviour and is validated against this oracle.
  """

  @behaviour Beancount.Engine

  alias Beancount.{Checker, Query, Renderer}

  @doc """
  Render directives to `.bean` text via `Beancount.Renderer`.

  ## Examples

      iex> Beancount.Engine.CLI.render([Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"])])
      "2026-01-01 open Assets:Bank USD\\n"

  """
  @impl Beancount.Engine
  def render(directives) when is_list(directives), do: Renderer.render(directives)

  @doc """
  Validate `.bean` text via `bean-check`.

  ## Examples

      text = "2026-01-01 open Assets:Bank USD\\n"

      if Beancount.Checker.available?() do
        {:ok, %Beancount.Result{status: :ok}} = Beancount.Engine.CLI.check(text)
      end

  """
  @impl Beancount.Engine
  def check(text) when is_binary(text), do: Checker.check_text(text)

  @doc """
  Validate a `.bean` file on disk via `bean-check`.

  ## Examples

      path = Path.join(System.tmp_dir!(), "cli_check.bean")
      File.write!(path, "2026-01-01 open Assets:Bank USD\\n")

      if Beancount.Checker.available?() do
        {:ok, _} = Beancount.Engine.CLI.check_file(path)
      end

  """
  @impl Beancount.Engine
  def check_file(path), do: Checker.check_file(path)

  @doc """
  Run a BQL query via `bean-query`.

  ## Examples

      text = "2026-01-01 open Assets:Bank USD\\n"

      if Beancount.Query.available?() do
        {:ok, _} = Beancount.Engine.CLI.query(text, "SELECT account GROUP BY account")
      end

  """
  @impl Beancount.Engine
  def query(text, bql) when is_binary(text) and is_binary(bql) do
    Query.query_text(text, bql)
  end
end
