defmodule Beancount.Engine.Elixir.Booking do
  @moduledoc false

  alias Beancount.CostSpec
  alias Beancount.Directives.Posting
  alias Beancount.Engine.Elixir.{Inventory, Lot}

  @spec reduce(Inventory.t(), String.t(), Posting.t(), String.t() | nil) ::
          {:ok, Inventory.t()} | {:error, String.t()}

  def reduce(inventory, account, posting, booking_method) do
    currency = posting.currency
    reduce_units = posting.amount |> Decimal.abs()
    cost_spec = Inventory.cost_spec_from_posting(posting)
    method = normalize_method(booking_method)

    inventory
    |> maybe_average(method, account, currency)
    |> do_reduce(account, currency, reduce_units, cost_spec, method, posting)
  end

  defp normalize_method(nil), do: "NONE"
  defp normalize_method(method), do: String.upcase(method)

  defp maybe_average(inventory, "AVERAGE", account, currency) do
    lots = get_lots(inventory, account, currency)

    case merge_average(lots) do
      nil -> inventory
      merged -> Inventory.update_lots_at(inventory, account, currency, [merged])
    end
  end

  defp maybe_average(inventory, _method, _account, _currency), do: inventory

  defp do_reduce(inventory, account, currency, reduce_units, cost_spec, "STRICT", posting) do
    lots = get_lots(inventory, account, currency)

    if is_nil(cost_spec) do
      fifo_consume(inventory, account, currency, reduce_units, lots)
    else
      strict_reduce(inventory, account, currency, reduce_units, cost_spec, lots, posting)
    end
  end

  defp do_reduce(inventory, account, currency, reduce_units, cost_spec, method, posting)
       when method in ["FIFO", "LIFO", "NONE"] and not is_nil(cost_spec) do
    lots = get_lots(inventory, account, currency)
    matches = matching_lots(lots, cost_spec)

    case matches do
      [] ->
        no_match_error(posting, lots)

      [{_lot, index}] ->
        consume_lot_at_index(inventory, account, currency, index, reduce_units)

      _ ->
        fifo_consume(inventory, account, currency, reduce_units, order_lots(lots, method))
    end
  end

  defp do_reduce(inventory, account, currency, reduce_units, _cost_spec, method, _posting) do
    lots = get_lots(inventory, account, currency)
    fifo_consume(inventory, account, currency, reduce_units, order_lots(lots, method))
  end

  defp strict_reduce(inventory, account, currency, reduce_units, cost_spec, lots, posting) do
    case matching_lots(lots, cost_spec) do
      [] ->
        no_match_error(posting, lots)

      matches when length(matches) > 1 ->
        {:error,
         "Ambiguous matches for #{inspect_posting_short(posting)}: #{format_matches(matches)}"}

      [{%Lot{}, index}] ->
        consume_lot_at_index(inventory, account, currency, index, reduce_units)
    end
  end

  defp no_match_error(posting, lots) do
    {:error,
     "No position matches #{inspect_posting(posting)} against balance (#{format_balance(lots)})"}
  end

  defp fifo_consume(inventory, account, currency, remaining, lots) do
    case consume_lots(remaining, lots) do
      {:done, remaining_lots} ->
        {:ok, Inventory.update_lots_at(inventory, account, currency, remaining_lots)}

      {:short, leftover, remaining_lots} ->
        short = %Lot{units: Decimal.negate(leftover), currency: currency, cost: nil}
        {:ok, Inventory.update_lots_at(inventory, account, currency, remaining_lots ++ [short])}
    end
  end

  defp consume_lots(remaining, lots) do
    consume_lots(remaining, lots, [])
  end

  defp consume_lots(remaining, [], acc) do
    if Decimal.equal?(remaining, 0) do
      {:done, Enum.reverse(acc)}
    else
      {:short, remaining, Enum.reverse(acc)}
    end
  end

  defp consume_lots(remaining, [lot | rest], acc) do
    cond do
      Decimal.equal?(remaining, 0) ->
        {:done, Enum.reverse(acc) ++ [lot | rest]}

      Decimal.lte?(lot.units, remaining) ->
        consume_lots(Decimal.sub(remaining, lot.units), rest, acc)

      true ->
        leftover = Decimal.sub(lot.units, remaining)
        {:done, Enum.reverse(acc) ++ [%{lot | units: leftover} | rest]}
    end
  end

  defp consume_lot_at_index(inventory, account, currency, index, reduce_units) do
    lots = get_lots(inventory, account, currency)
    lot = Enum.at(lots, index)

    if is_nil(lot) or Decimal.gt?(reduce_units, lot.units) do
      {:error, "Insufficient units for reduction"}
    else
      {prefix, rest} = Enum.split(lots, index)

      {matched, suffix} =
        case rest do
          [h | t] -> {[h], t}
          [] -> {[], []}
        end

      case consume_lots(reduce_units, matched) do
        {:done, consumed} ->
          {:ok,
           Inventory.update_lots_at(inventory, account, currency, prefix ++ consumed ++ suffix)}

        {:short, _, _} ->
          {:error, "Insufficient units for reduction"}
      end
    end
  end

  defp get_lots(inventory, account, currency) do
    inventory |> Map.get(account, %{}) |> Map.get(currency, [])
  end

  defp order_lots(lots, "LIFO"), do: Enum.reverse(lots)
  defp order_lots(lots, _), do: lots

  defp matching_lots(lots, cost_spec) do
    lots
    |> Enum.with_index()
    |> Enum.filter(fn {lot, _} -> lot_matches_cost?(lot, cost_spec) end)
  end

  defp lot_matches_cost?(%Lot{cost: lot_cost}, cost_spec) do
    Inventory.cost_specs_match?(lot_cost, cost_spec) or
      label_match?(lot_cost, cost_spec) or date_only_match?(lot_cost, cost_spec)
  end

  defp label_match?(%CostSpec{label: label}, %CostSpec{label: label})
       when is_binary(label),
       do: true

  defp label_match?(_, _), do: false

  defp date_only_match?(%CostSpec{date: date, per_amount: nil}, %CostSpec{
         date: date,
         per_amount: nil
       })
       when not is_nil(date),
       do: true

  defp date_only_match?(_, _), do: false

  defp merge_average([first | rest]) do
    Enum.reduce(rest, first, fn lot, acc ->
      units = Decimal.add(acc.units, lot.units)

      %Lot{
        units: units,
        currency: acc.currency,
        cost: merge_cost(acc.cost, lot.cost, acc.units, lot.units)
      }
    end)
  end

  defp merge_average([]), do: nil

  defp merge_cost(nil, cost, _, _), do: cost

  defp merge_cost(cost, nil, _, _), do: cost

  defp merge_cost(%CostSpec{} = left, %CostSpec{} = right, left_units, right_units) do
    total =
      Decimal.add(
        Decimal.mult(left.per_amount || Decimal.new(0), left_units),
        Decimal.mult(right.per_amount || Decimal.new(0), right_units)
      )

    total_units = Decimal.add(left_units, right_units)
    per = Decimal.div(total, total_units)

    %CostSpec{
      per_amount: per,
      per_currency: left.per_currency || right.per_currency,
      merge: false
    }
  end

  defp format_balance(lots) do
    lots
    |> Enum.map_join(", ", fn %Lot{units: u, currency: c} -> "#{u} #{c}" end)
  end

  defp format_matches(matches) do
    matches
    |> Enum.map_join(", ", fn {lot, _} -> format_lot(lot) end)
  end

  defp format_lot(%Lot{units: units, currency: currency, cost: cost}) do
    "#{units} #{currency} #{format_cost(cost)}"
  end

  defp format_cost(nil), do: ""
  defp format_cost(%CostSpec{label: label}) when is_binary(label), do: "{#{inspect(label)}}"

  defp format_cost(%CostSpec{per_amount: per, per_currency: cur}),
    do: "{#{per} #{cur}}"

  defp inspect_posting(%Posting{} = posting) do
    "Posting(account='#{posting.account}', units=#{posting.amount} #{posting.currency})"
  end

  defp inspect_posting_short(%Posting{} = posting) do
    cost = Inventory.cost_spec_from_posting(posting)
    "#{posting.amount} #{posting.currency} #{format_cost(cost)}"
  end
end
