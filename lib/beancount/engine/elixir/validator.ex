defmodule Beancount.Engine.Elixir.Validator do
  @moduledoc false

  alias Beancount.Directives.{Close, Open, Transaction}
  alias Beancount.Engine.Elixir.PostingAmount
  alias Beancount.Result

  @spec validate([Beancount.Directive.t()]) :: {:ok, Result.t()} | {:error, Result.t()}
  def validate(directives) do
    directives
    |> Enum.reduce(initial_state(), &apply_directive/2)
    |> build_result()
  end

  defp initial_state, do: %{opens: MapSet.new(), closed: MapSet.new(), errors: []}

  defp apply_directive(%Open{account: account}, acc) do
    if MapSet.member?(acc.opens, account) do
      add_error(acc, "Duplicate open for account #{account}")
    else
      %{acc | opens: MapSet.put(acc.opens, account)}
    end
  end

  defp apply_directive(%Close{account: account}, acc) do
    cond do
      MapSet.member?(acc.closed, account) ->
        add_error(acc, "Duplicate close for account #{account}")

      not MapSet.member?(acc.opens, account) ->
        add_error(acc, "Unopened account #{account} closed")

      true ->
        %{acc | closed: MapSet.put(acc.closed, account)}
    end
  end

  defp apply_directive(%Transaction{postings: postings}, acc) do
    acc
    |> validate_transaction_postings(postings)
    |> validate_balance(postings)
  end

  defp apply_directive(_directive, acc), do: acc

  defp validate_transaction_postings(acc, postings) do
    Enum.reduce(postings, acc, &validate_posting_account(&2, &1))
  end

  defp validate_posting_account(acc, posting) do
    account = posting.account

    cond do
      not MapSet.member?(acc.opens, account) ->
        add_error(acc, "Account #{account} used but never opened")

      MapSet.member?(acc.closed, account) ->
        add_error(acc, "Account #{account} used after close")

      true ->
        acc
    end
  end

  defp validate_balance(acc, postings) do
    totals = PostingAmount.transaction_totals(postings)

    Enum.reduce(totals, acc, fn {_currency, total}, acc ->
      if Decimal.equal?(total, Decimal.new(0)) do
        acc
      else
        add_error(acc, "Transaction does not balance in one currency")
      end
    end)
  end

  defp add_error(acc, message) do
    %{acc | errors: [%{line: nil, message: message} | acc.errors]}
  end

  defp build_result(%{errors: []}) do
    {:ok,
     %Result{
       status: :ok,
       exit_status: 0,
       stdout: "",
       stderr: "",
       normalized: %{status: :ok, errors: []}
     }}
  end

  defp build_result(%{errors: errors}) do
    normalized = %{
      status: :error,
      errors: errors |> Enum.reverse() |> Enum.sort_by(&{&1.message, &1.line || 0})
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
