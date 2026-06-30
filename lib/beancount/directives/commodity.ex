defmodule Beancount.Directives.Commodity do
  @moduledoc """
  The `commodity` directive declares a currency or commodity.

      2026-01-01 commodity USD

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
