defmodule Beancount.Engine.Elixir.PadResolver do
  @moduledoc false

  alias Beancount.Directives.{Balance, Pad, Transaction}
  alias Beancount.Engine.Elixir.Inventory

  alias Beancount.Directives.Posting

  @spec resolve_pad(Pad.t(), Balance.t(), Inventory.t()) ::
          {:ok, Inventory.t(), Transaction.t() | nil}
  def resolve_pad(
        %Pad{account: pad_account, source_account: source},
        %Balance{
          account: balance_account,
          amount: asserted,
          currency: currency,
          date: balance_date
        },
        inventory
      )
      when pad_account == balance_account do
    current = Inventory.balance(inventory, pad_account, currency)
    difference = Decimal.sub(asserted, current)

    case Decimal.compare(difference, Decimal.new(0)) do
      :eq ->
        {:ok, inventory, nil}

      _compare ->
        txn = %Transaction{
          date: balance_date,
          flag: nil,
          payee: nil,
          narration: "Pad",
          postings: [
            %Posting{
              account: pad_account,
              amount: difference,
              currency: currency,
              cost: nil,
              price: nil,
              flag: nil,
              metadata: %{}
            },
            %Posting{
              account: source,
              amount: Decimal.negate(difference),
              currency: currency,
              cost: nil,
              price: nil,
              flag: nil,
              metadata: %{}
            }
          ],
          tags: [],
          links: [],
          metadata: %{}
        }

        {:ok, inventory, txn}
    end
  end
end
