defmodule Beancount.Directives.Commodity do
  @moduledoc """
  The `commodity` directive declares a currency or commodity.

  See the [Beancount Commodity directive](https://beancount.github.io/docs/beancount_language_syntax/#commodity).

  ## Beancount syntax

      2026-01-01 commodity USD
        name: "US Dollar"
        asset-class: "cash"

  General form: `YYYY-MM-DD commodity Currency`

  ## Elixir struct

      %Beancount.Directives.Commodity{
        date: ~D[2026-01-01],
        currency: "USD",
        metadata: %{"name" => "US Dollar", "asset-class" => "cash"}
      }

  Or use `Beancount.commodity/3`:

      Beancount.commodity(~D[2026-01-01], "USD",
        metadata: %{"name" => "US Dollar", "asset-class" => "cash"}
      )

  ## Fields

    * `date` - `Date.t()` associated with the commodity (often its introduction
      date; used for ordering, not validation).
    * `currency` - commodity symbol, e.g. `"USD"`, `"AAPL"`, `"HOOL"`.
    * `metadata` - optional map for descriptive attributes (`name`, `asset-class`,
      etc.) gathered by plugins and reports.
  """

  alias Beancount.Renderer

  @enforce_keys [:date, :currency]
  defstruct date: nil, currency: nil, metadata: %{}

  @type t :: %__MODULE__{
          date: Date.t(),
          currency: String.t(),
          metadata: map()
        }

  defimpl Beancount.Directive do
    def to_bean(%{date: date, currency: currency, metadata: metadata}) do
      header = Renderer.format_date(date) <> " commodity " <> currency
      Renderer.lines_to_fragment([header | Renderer.render_metadata(metadata)])
    end
  end
end
