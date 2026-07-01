defmodule Beancount.Engine.Elixir.ErrorCategory do
  @moduledoc false

  @spec categorize(%{line: term(), message: String.t()}) :: atom()
  def categorize(%{message: message}) do
    Enum.find_value(rules(), :other, fn {category, predicate} ->
      if predicate.(message), do: category
    end)
  end

  defp rules do
    [
      {:duplicate_open, &duplicate_open?/1},
      {:duplicate_close, &duplicate_close?/1},
      {:unopened_close, &unopened_close?/1},
      {:unknown_account, &unknown_account?/1},
      {:used_after_close, &used_after_close?/1},
      {:balance_failed, &balance_failed?/1},
      {:duplicate_balance, &duplicate_balance?/1},
      {:invalid_currency, &invalid_currency?/1},
      {:invalid_units, &invalid_units?/1},
      {:invalid_token, &invalid_token?/1},
      {:unbalanced, &unbalanced?/1},
      {:booking_no_match, &booking_no_match?/1},
      {:booking_ambiguous, &booking_ambiguous?/1},
      {:booking_insufficient, &booking_insufficient?/1},
      {:include_not_found, &include_error?/1},
      {:invalid_option, &option_error?/1}
    ]
  end

  defp duplicate_open?(msg),
    do: String.contains?(msg, "Duplicate open")

  defp duplicate_close?(msg),
    do: String.contains?(msg, "Duplicate close")

  defp unopened_close?(msg),
    do: String.contains?(msg, "Unopened account") and String.contains?(msg, "closed")

  defp unknown_account?(msg),
    do:
      String.contains?(msg, "unknown account") or String.contains?(msg, "never opened") or
        String.contains?(msg, "Invalid reference to unknown account")

  defp used_after_close?(msg), do: String.contains?(msg, "after close")

  defp balance_failed?(msg),
    do: String.contains?(msg, "Balance failed") or String.contains?(msg, "balance failed")

  defp duplicate_balance?(msg), do: String.contains?(msg, "Duplicate balance assertion")

  defp invalid_currency?(msg),
    do: String.contains?(msg, "Invalid currency")

  defp invalid_units?(msg), do: String.contains?(msg, "Could not resolve units currency")

  defp invalid_token?(msg), do: String.contains?(msg, "Invalid token")

  defp unbalanced?(msg),
    do:
      String.contains?(msg, "does not balance") or
        String.contains?(msg, "Transaction does not balance")

  defp booking_no_match?(msg),
    do: String.contains?(msg, "No position matches")

  defp booking_ambiguous?(msg),
    do: String.contains?(msg, "Ambiguous matches")

  defp booking_insufficient?(msg),
    do:
      String.contains?(msg, "Not enough lots") or
        String.contains?(msg, "Insufficient units")

  defp include_error?(msg),
    do: String.contains?(msg, "does not match any files")

  defp option_error?(msg),
    do: String.starts_with?(msg, "Error for option") or String.contains?(msg, "syntax error")
end
