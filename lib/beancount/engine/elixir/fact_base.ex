defmodule Beancount.Engine.Elixir.FactBase do
  @moduledoc false

  alias Beancount.Directives.{Open, Transaction}
  alias Beancount.Engine.Elixir.{Inventory, Ledger}

  @enforce_keys [:ledger, :directives, :opens, :inventory, :transaction_accounts]
  defstruct ledger: nil,
            directives: [],
            opens: %{},
            inventory: %{},
            transaction_accounts: MapSet.new(),
            postings: [],
            lots: []

  @type t :: %__MODULE__{
          ledger: Ledger.t(),
          directives: [Beancount.Directive.t()],
          opens: %{optional(String.t()) => Open.t()},
          inventory: Inventory.t(),
          transaction_accounts: MapSet.t(),
          postings: [map()],
          lots: [map()]
        }

  @spec from_ledger(Ledger.t(), [Beancount.Directive.t()]) :: t()
  def from_ledger(%Ledger{} = ledger, directives) when is_list(directives) do
    %__MODULE__{
      ledger: ledger,
      directives: directives,
      opens: ledger.opens,
      inventory: ledger.inventory,
      transaction_accounts: transaction_accounts(directives),
      postings: postings_from_directives(directives),
      lots: lots_from_inventory(ledger.inventory)
    }
  end

  defp transaction_accounts(directives) do
    Enum.reduce(directives, MapSet.new(), &accumulate_transaction_accounts/2)
  end

  defp accumulate_transaction_accounts(%Transaction{postings: postings}, set) do
    Enum.reduce(postings, set, fn posting, acc ->
      if posting_material?(posting), do: MapSet.put(acc, posting.account), else: acc
    end)
  end

  defp accumulate_transaction_accounts(_directive, set), do: set

  defp posting_material?(%{amount: %Decimal{}, currency: currency}) when is_binary(currency),
    do: true

  defp posting_material?(_), do: false

  defp postings_from_directives(directives) do
    Enum.flat_map(directives, fn
      %Transaction{
        date: date,
        flag: flag,
        payee: payee,
        narration: narration,
        postings: postings
      } ->
        Enum.map(postings, fn posting ->
          %{
            date: date,
            flag: flag,
            payee: payee,
            narration: narration,
            account: posting.account,
            amount: posting.amount,
            currency: posting.currency,
            cost: posting.cost,
            price: posting.price
          }
        end)

      _ ->
        []
    end)
  end

  defp lots_from_inventory(inventory) do
    inventory
    |> Inventory.holdings()
    |> Enum.flat_map(fn {account, {units, unit_currency, cost, cost_currency}} ->
      [
        %{
          account: account,
          currency: unit_currency,
          units: units,
          cost_per: cost,
          cost_currency: cost_currency,
          date: cost_date(cost),
          label: cost_label(cost)
        }
      ]
    end)
  end

  defp cost_date(%Beancount.CostSpec{date: %Date{} = date}), do: date
  defp cost_date(_), do: nil

  defp cost_label(%Beancount.CostSpec{label: label}) when is_binary(label), do: label
  defp cost_label(_), do: nil
end
