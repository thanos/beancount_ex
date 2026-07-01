defmodule Beancount.Engine.Elixir.Inventory do
  @moduledoc false

  alias Beancount.CostSpec
  alias Beancount.Directives.Posting
  alias Beancount.Engine.Elixir.{Booking, Lot}

  @type t :: %{optional(String.t()) => %{optional(String.t()) => [Lot.t()]}}

  @spec new() :: t()
  def new, do: %{}

  @spec balance(t(), String.t(), String.t()) :: Decimal.t()
  def balance(inventory, account, currency) do
    inventory
    |> Map.get(account, %{})
    |> Map.get(currency, [])
    |> Enum.reduce(Decimal.new(0), fn %Lot{units: units}, acc ->
      Decimal.add(acc, units)
    end)
  end

  @spec positions(t()) :: %{String.t() => [{String.t(), Decimal.t()}]}
  def positions(inventory) do
    Enum.reduce(inventory, %{}, fn {account, currencies}, acc ->
      put_position_pairs(acc, account, currencies)
    end)
  end

  @spec holdings(t()) :: %{String.t() => {Decimal.t(), String.t(), Decimal.t(), String.t()}}
  def holdings(inventory) do
    Enum.reduce(inventory, %{}, fn {account, currencies}, acc ->
      Enum.reduce(currencies, acc, &put_holding_summary(account, &1, &2))
    end)
  end

  defp put_position_pairs(acc, account, currencies) do
    case currency_position_pairs(currencies) do
      [] -> acc
      pairs -> Map.put(acc, account, pairs)
    end
  end

  defp currency_position_pairs(currencies) do
    Enum.flat_map(currencies, fn {currency, lots} ->
      total = lot_units_total(lots)
      if Decimal.equal?(total, 0), do: [], else: [{currency, total}]
    end)
  end

  defp lot_units_total(lots) do
    Enum.reduce(lots, Decimal.new(0), fn %Lot{units: units}, sum ->
      Decimal.add(sum, units)
    end)
  end

  defp put_holding_summary(account, {currency, lots}, acc) do
    case summarize_lots(lots, currency) do
      nil -> acc
      summary -> Map.put(acc, account, summary)
    end
  end

  @spec apply_posting(t(), String.t(), Posting.t(), String.t() | nil) ::
          {:ok, t()} | {:error, String.t()}
  def apply_posting(inventory, account, posting, booking_method) do
    case posting.amount do
      %Decimal{} = amount ->
        if Decimal.positive?(amount) do
          {:ok, add_lot(inventory, account, posting)}
        else
          Booking.reduce(inventory, account, posting, booking_method)
        end

      _ ->
        {:ok, inventory}
    end
  end

  defp add_lot(inventory, account, posting) do
    lot = %Lot{
      units: posting.amount,
      currency: posting.currency,
      cost: lot_cost(posting)
    }

    update_lots(inventory, account, posting.currency, fn lots -> lots ++ [lot] end)
  end

  defp update_lots(inventory, account, currency, fun) do
    account_lots = Map.get(inventory, account, %{})
    lots = Map.get(account_lots, currency, [])
    lots = fun.(lots)

    account_lots =
      if lots == [] do
        Map.delete(account_lots, currency)
      else
        Map.put(account_lots, currency, lots)
      end

    if account_lots == %{} do
      Map.delete(inventory, account)
    else
      Map.put(inventory, account, account_lots)
    end
  end

  def update_lots_at(inventory, account, currency, lots),
    do: update_lots(inventory, account, currency, fn _ -> lots end)

  def lot_cost(%Posting{cost: %CostSpec{} = cost} = posting) do
    enrich_cost_from_price(cost, posting.price)
  end

  def lot_cost(_), do: nil

  defp enrich_cost_from_price(%CostSpec{per_amount: nil} = cost, %{
         amount: %Decimal{} = price_amount,
         currency: price_currency,
         type: :unit
       })
       when is_binary(price_currency) do
    %{cost | per_amount: price_amount, per_currency: price_currency}
  end

  defp enrich_cost_from_price(cost, _), do: cost

  defp summarize_lots(lots, currency) do
    {units, cost_total, cost_currency} =
      Enum.reduce(lots, {Decimal.new(0), Decimal.new(0), nil}, fn lot, {u, c, cc} ->
        u = Decimal.add(u, lot.units)

        {basis, basis_currency} = lot_cost_basis(lot)
        c = Decimal.add(c, basis)
        cc = cc || basis_currency
        {u, c, cc}
      end)

    if Decimal.equal?(units, 0),
      do: nil,
      else: {units, currency, cost_total, cost_currency || currency}
  end

  defp lot_cost_basis(%Lot{
         units: units,
         cost: %CostSpec{per_amount: %Decimal{} = per, per_currency: cur}
       })
       when is_binary(cur) do
    {Decimal.mult(units, per), cur}
  end

  defp lot_cost_basis(%Lot{
         units: _units,
         cost: %CostSpec{total_amount: %Decimal{} = total, total_currency: cur}
       })
       when is_binary(cur) do
    {total, cur}
  end

  defp lot_cost_basis(%Lot{units: units, currency: currency}), do: {units, currency}

  def cost_specs_match?(nil, nil), do: true

  def cost_specs_match?(%CostSpec{} = left, %CostSpec{} = right) do
    left.per_amount == right.per_amount and left.per_currency == right.per_currency and
      left.total_amount == right.total_amount and left.total_currency == right.total_currency and
      left.date == right.date and left.label == right.label
  end

  def cost_specs_match?(_, _), do: false

  def cost_spec_from_posting(%Posting{cost: %CostSpec{} = cost}), do: cost
  def cost_spec_from_posting(_), do: nil
end
