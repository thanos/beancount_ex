defmodule Beancount.Engine.Elixir.BalanceCheck do
  @moduledoc false

  alias Beancount.Directives.Balance
  alias Beancount.Engine.Elixir.{Inventory, Tolerance}

  @spec check(
          Balance.t(),
          Inventory.t(),
          map(),
          map(),
          term(),
          map()
        ) :: [map()]
  def check(%Balance{} = balance, inventory, options, assertions, parent_accounts, opens) do
    []
    |> maybe_parent_error(balance, parent_accounts)
    |> Kernel.++(duplicate_errors(balance, assertions))
    |> Kernel.++(currency_errors(balance, opens))
    |> Kernel.++(balance_errors(balance, inventory, options))
  end

  defp maybe_parent_error(errors, %Balance{account: account}, parent_accounts) do
    if MapSet.member?(parent_accounts, account) do
      errors ++ [%{line: nil, message: "Invalid token: '#{parent_segment(account)}'"}]
    else
      errors
    end
  end

  defp parent_segment(account) do
    account |> String.split(":") |> List.first()
  end

  defp duplicate_errors(
         %Balance{account: account, currency: currency, date: date, amount: amount},
         assertions
       ) do
    key = {account, currency, date}

    case Map.get(assertions, key) do
      nil ->
        []

      ^amount ->
        []

      _other ->
        [%{line: nil, message: "Duplicate balance assertion with different amounts"}]
    end
  end

  defp currency_errors(%Balance{currency: currency, account: account}, opens) do
    case Map.get(opens, account) do
      %Beancount.Directives.Open{currencies: []} ->
        []

      %Beancount.Directives.Open{currencies: currencies} ->
        if currency in currencies do
          []
        else
          [%{line: nil, message: "Invalid currency '#{currency}' for Balance directive:"}]
        end

      _ ->
        []
    end
  end

  defp balance_errors(%Balance{} = balance, inventory, options) do
    actual = Inventory.balance(inventory, balance.account, balance.currency)

    tolerance =
      balance.tolerance || Tolerance.infer(options, balance.currency, [balance.amount, actual])

    if Tolerance.within?(actual, balance.amount, tolerance) do
      []
    else
      signed_diff = Decimal.sub(balance.amount, actual)
      diff = Decimal.abs(signed_diff)
      direction = if Decimal.negative?(signed_diff), do: "too much", else: "too little"

      [
        %{
          line: nil,
          message:
            "Balance failed for '#{balance.account}': expected #{format_amount(balance)} != accumulated #{format_amount(%{balance | amount: actual})} (#{format_decimal(diff)} #{direction})"
        }
      ]
    end
  end

  defp format_amount(%{amount: amount, currency: currency}) do
    "#{format_decimal(amount)} #{currency}"
  end

  defp format_decimal(%Decimal{} = d), do: Beancount.Renderer.format_decimal(d)
end
