defmodule Beancount.Directives.Query do
  @moduledoc """
  The `query` directive stores a named BQL query in the ledger.

      2026-01-01 query "monthly" "SELECT account, sum(position) GROUP BY account"

  """

  alias Beancount.Renderer

  @enforce_keys [:date, :name, :bql]
  defstruct date: nil, name: nil, bql: nil, metadata: %{}

  @type t :: %__MODULE__{
          date: Date.t(),
          name: String.t(),
          bql: String.t(),
          metadata: map()
        }

  defimpl Beancount.Directive do
    def to_bean(%{date: date, name: name, bql: bql} = query) do
      header =
        Renderer.format_date(date) <>
          " query " <>
          Renderer.quote_string(name) <> " " <> Renderer.quote_string(bql)

      Renderer.lines_to_fragment([header | Renderer.render_metadata(query.metadata)])
    end
  end
end
