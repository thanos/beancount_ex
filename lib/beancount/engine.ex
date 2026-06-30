defmodule Beancount.Engine do
  @moduledoc """
  Behaviour that every Beancount execution backend must implement.

  The behaviour is the seam that lets `beancount_ex` swap its backend without
  changing the public `Beancount.*` API:

      Beancount  ->  Engine.CLI    (v0.1, wraps real Beancount)
      Beancount  ->  Engine.Elixir (future, native)
      Beancount  ->  Engine.Rust   (future, native)

  The engine is selected via configuration:

      config :beancount_ex, engine: Beancount.Engine.CLI

  """

  @doc """
  Render a directive stream into `.bean` text.
  """
  @callback render(term()) :: binary()

  @doc """
  Check a `.bean` document, returning a normalized `Beancount.Result`.
  """
  @callback check(binary()) ::
              {:ok, Beancount.Result.t()} | {:error, Beancount.Result.t()}

  @doc """
  Return the currently configured engine module.

  ## Examples

      iex> Beancount.Engine.configured()
      Beancount.Engine.CLI

  """
  @spec configured() :: module()
  def configured do
    Application.get_env(:beancount_ex, :engine, Beancount.Engine.CLI)
  end
end
