defmodule Beancount.Directives.Balance do
  @moduledoc """
  The `balance` directive asserts an account balance at a date.

      2026-01-31 balance Assets:Bank   5000 USD

  """

  alias Beancount.Renderer

  @enforce_keys [:date, :account, :amount, :currency]
  defstruct date: nil, account: nil, amount: nil, currency: nil, metadata: %{}

  @type t :: %__MODULE__{
          date: Date.t(),
          account: String.t(),
          amount: Decimal.t(),
          currency: String.t(),
          metadata: map()
        }

  defimpl Beancount.Directive do
    def to_bean(%{date: date, account: account, amount: amount, currency: currency} = balance) do
      header =
        Renderer.format_date(date) <>
          " balance " <>
          account <> "  " <> Renderer.format_decimal(amount) <> " " <> currency

      Renderer.lines_to_fragment([header | Renderer.render_metadata(balance.metadata)])
    end
  end
end
