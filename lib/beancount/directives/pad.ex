defmodule Beancount.Directives.Pad do
  @moduledoc """
  The `pad` directive inserts an automatic transaction before the next balance.

      2025-12-20 pad Assets:Cash Equity:Opening

  """

  alias Beancount.Renderer

  @enforce_keys [:date, :account, :source_account]
  defstruct date: nil, account: nil, source_account: nil, metadata: %{}

  @type t :: %__MODULE__{
          date: Date.t(),
          account: String.t(),
          source_account: String.t(),
          metadata: map()
        }

  defimpl Beancount.Directive do
    def to_bean(%{date: date, account: account, source_account: source} = pad) do
      header =
        Renderer.format_date(date) <>
          " pad " <> account <> " " <> source

      Renderer.lines_to_fragment([header | Renderer.render_metadata(pad.metadata)])
    end
  end
end
