defmodule Beancount.Engine.Elixir.Validator do
  @moduledoc false

  alias Beancount.Engine.Elixir.Ledger
  alias Beancount.Result

  @spec validate([Beancount.Directive.t()], keyword()) :: {:ok, Result.t()} | {:error, Result.t()}
  def validate(directives, opts \\ []) do
    opts
    |> Ledger.new()
    |> Ledger.process(directives)
    |> build_result()
  end

  defp build_result(%Ledger{} = ledger) do
    errors = Ledger.errors(ledger)

    if errors == [] do
      {:ok,
       %Result{
         status: :ok,
         exit_status: 0,
         stdout: "",
         stderr: "",
         normalized: %{status: :ok, errors: []}
       }}
    else
      normalized = %{
        status: :error,
        errors: errors |> Enum.sort_by(&{&1.message, &1.line || 0})
      }

      {:error,
       %Result{
         status: :error,
         exit_status: 1,
         stdout: "",
         stderr: "",
         normalized: normalized
       }}
    end
  end
end
