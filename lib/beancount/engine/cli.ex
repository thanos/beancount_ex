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

  alias Beancount.{Checker, Renderer}

  @impl Beancount.Engine
  def render(directives) when is_list(directives), do: Renderer.render(directives)

  @impl Beancount.Engine
  def check(text) when is_binary(text), do: Checker.check_text(text)
end
