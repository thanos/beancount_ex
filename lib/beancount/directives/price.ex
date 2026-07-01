defmodule Beancount.Directives.Price do
  @moduledoc """
  The `price` directive records the price of a commodity in another currency.

  See [Prices](https://beancount.github.io/docs/beancount_language_syntax/#prices).

  ## Beancount syntax

      2026-01-01 price USD 1.20 CAD

  General form: `YYYY-MM-DD price Commodity Amount Currency`

  Reads as: one unit of `commodity` equals `amount` units of `currency`.

  ## Elixir struct

      %Beancount.Directives.Price{
        date: ~D[2026-01-01],
        commodity: "USD",
        amount: Decimal.new("1.20"),
        currency: "CAD",
        metadata: %{}
      }

  Or use `Beancount.price/5`:

      Beancount.price(~D[2026-01-01], "USD", Decimal.new("1.20"), "CAD")

  ## Fields

    * `date` - `Date.t()` the price is effective (end of day in Beancount).
    * `commodity` - priced commodity symbol, e.g. `"USD"` or `"HOOL"`.
    * `amount` - `Decimal.t()` price value (unsigned).
    * `currency` - quote currency the amount is expressed in.
    * `metadata` - optional map rendered below the directive.
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
