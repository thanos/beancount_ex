defmodule Beancount.Directives.Balance do
  @moduledoc """
  The `balance` directive asserts an account balance at a date.

      2026-01-31 balance Assets:Bank   5000 USD
      2026-01-31 balance Assets:Bank   1.5 ~ 0.5 USD

  An optional `tolerance` allows an explicit assertion tolerance.
  """

  alias Beancount.Renderer

  @enforce_keys [:date, :account, :amount, :currency]
  defstruct date: nil, account: nil, amount: nil, currency: nil, tolerance: nil, metadata: %{}

  @type t :: %__MODULE__{
          date: Date.t(),
          account: String.t(),
          amount: Decimal.t(),
          currency: String.t(),
          tolerance: Decimal.t() | nil,
          metadata: map()
        }

  defimpl Beancount.Directive do
    def to_bean(%{date: date, account: account, amount: amount, currency: currency} = balance) do
      amount_text = Renderer.format_decimal(amount)

      tolerance_text =
        case balance.tolerance do
          %Decimal{} = tolerance -> " ~ " <> Renderer.format_decimal(tolerance)
          _ -> ""
        end

      header =
        Renderer.format_date(date) <>
          " balance " <>
          account <> "  " <> amount_text <> tolerance_text <> " " <> currency

      Renderer.lines_to_fragment([header | Renderer.render_metadata(balance.metadata)])
    end
  end
end
