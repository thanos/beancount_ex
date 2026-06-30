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
  Run a BQL query against a `.bean` document.

  The first argument is the ledger text, the second is a Beancount Query
  Language (BQL) string. Returns a neutral, engine-independent
  `Beancount.Query.Result` on success, or a `Beancount.Result` describing the
  failure otherwise.

  Every engine - including future native engines - must implement this so the
  oracle contract stays uniform across backends.
  """
  @callback query(binary(), binary()) ::
              {:ok, Beancount.Query.Result.t()} | {:error, Beancount.Result.t()}

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
