defmodule Beancount.Directives.Price do
  @moduledoc """
  The `price` directive records the price of a commodity.

      2026-01-01 price USD 1.20 CAD

  """

  alias Beancount.Renderer

  @enforce_keys [:date, :commodity, :amount, :currency]
  defstruct date: nil, commodity: nil, amount: nil, currency: nil, metadata: %{}

  @type t :: %__MODULE__{
          date: Date.t(),
          commodity: String.t(),
          amount: Decimal.t(),
          currency: String.t(),
          metadata: map()
        }

  defimpl Beancount.Directive do
    def to_bean(%{date: date, commodity: commodity, amount: amount, currency: currency} = price) do
      header =
        Renderer.format_date(date) <>
          " price " <>
          commodity <> " " <> Renderer.format_decimal(amount) <> " " <> currency

      Renderer.lines_to_fragment([header | Renderer.render_metadata(price.metadata)])
    end
  end
end
