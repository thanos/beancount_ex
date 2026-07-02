defmodule Beancount.Engine.Elixir.PostingAmount do
  @moduledoc false

  alias Beancount.CostSpec
  alias Beancount.Directives.Posting

  @spec balance_contribution(Posting.t()) :: {String.t(), Decimal.t()} | nil
  def balance_contribution(%Posting{} = posting) do
    cond do
      contribution = cost_contribution(posting) ->
        contribution

      contribution = price_contribution(posting) ->
        contribution

      true ->
        amount_currency_contribution(posting)
    end
  end

  @spec expand_postings([Posting.t()]) :: [Posting.t()]
  def expand_postings(postings) do
    case infer_elided_posting(postings) do
      nil ->
        postings

      {index, amount, currency} ->
        List.update_at(postings, index, &%{&1 | amount: amount, currency: currency})
    end
  end

  @spec transaction_totals([Posting.t()]) :: %{String.t() => Decimal.t()}
  def transaction_totals(postings) do
    postings
    |> expand_postings()
    |> Enum.reduce(%{}, fn posting, totals ->
      case balance_contribution(posting) do
        {currency, amount} ->
          Map.update(totals, currency, amount, &Decimal.add(&1, amount))

        nil ->
          totals
      end
    end)
  end

  defp infer_elided_posting(postings) do
    {totals, elided} = fold_posting_totals(postings)

    case {elided, single_nonzero_currency(totals)} do
      {[{index, _posting}], {currency, total}} ->
        {index, Decimal.negate(total), currency}

      _ ->
        nil
    end
  end

  defp fold_posting_totals(postings) do
    Enum.reduce(Enum.with_index(postings), {%{}, []}, &fold_posting_total/2)
  end

  defp fold_posting_total({posting, index}, {totals, elided}) do
    case balance_contribution(posting) do
      {currency, amount} ->
        {Map.update(totals, currency, amount, &Decimal.add(&1, amount)), elided}

      nil when is_nil(posting.amount) ->
        {totals, [{index, posting} | elided]}

      nil ->
        {totals, elided}
    end
  end

  defp single_nonzero_currency(totals) do
    case Enum.reject(totals, fn {_, total} -> Decimal.equal?(total, 0) end) do
      [{currency, total}] -> {currency, total}
      _ -> nil
    end
  end

  defp amount_currency_contribution(%Posting{amount: %Decimal{} = amount, currency: currency})
       when is_binary(currency),
       do: {currency, amount}

  defp amount_currency_contribution(_), do: nil

  defp cost_contribution(%Posting{cost: %CostSpec{} = cost} = posting) do
    case cost_basis_from_spec(posting.amount, cost) do
      {currency, amount} -> {currency, amount}
      nil -> nil
    end
  end

  defp cost_contribution(_), do: nil

  defp cost_basis_from_spec(%Decimal{} = units, %CostSpec{
         per_amount: %Decimal{} = per_amount,
         per_currency: per_currency
       })
       when is_binary(per_currency) do
    {per_currency, Decimal.mult(units, per_amount)}
  end

  defp cost_basis_from_spec(_units, %CostSpec{
         total_amount: %Decimal{} = total_amount,
         total_currency: total_currency
       })
       when is_binary(total_currency) do
    {total_currency, total_amount}
  end

  defp cost_basis_from_spec(_units, _cost), do: nil

  defp price_contribution(%Posting{
         amount: %Decimal{} = amount,
         price: %{amount: price_amount, currency: price_currency, type: :unit}
       })
       when is_binary(price_currency) do
    {price_currency, Decimal.mult(amount, price_amount)}
  end

  defp price_contribution(%Posting{
         price: %{amount: total_amount, currency: price_currency, type: :total}
       })
       when is_binary(price_currency) do
    {price_currency, total_amount}
  end

  defp price_contribution(_), do: nil
end
