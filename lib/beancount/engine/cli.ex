defmodule Beancount.Engine.CLI do
  @moduledoc """
  The v0.1 engine: a thin wrapper around the real Beancount `bean-check` CLI.

  This is the initial behavioral oracle. Rendering is delegated to
  `Beancount.Renderer` and checking is delegated to `Beancount.Checker`, which
  shells out to `bean-check`.

  Future native engines (`Beancount.Engine.Elixir`, `Beancount.Engine.Rust`)
  will implement the same `Beancount.Engine` behaviour and can be validated
  against this oracle.
  """

  @behaviour Beancount.Engine

  alias Beancount.{Checker, Query, Renderer}

  @impl Beancount.Engine
  def render(directives) when is_list(directives), do: Renderer.render(directives)

  @impl Beancount.Engine
  def check(text) when is_binary(text), do: Checker.check_text(text)

  @impl Beancount.Engine
  def check_file(path), do: Checker.check_file(path)

  @impl Beancount.Engine
  def query(text, bql) when is_binary(text) and is_binary(bql) do
    Query.query_text(text, bql)
  end
end
