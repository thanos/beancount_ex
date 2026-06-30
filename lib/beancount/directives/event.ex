defmodule Beancount.Directives.Event do
  @moduledoc """
  The `event` directive tracks the value of a named variable over time.

      2026-01-01 event "location" "New York"

  """

  alias Beancount.Renderer

  @enforce_keys [:date, :type, :description]
  defstruct date: nil, type: nil, description: nil, metadata: %{}

  @type t :: %__MODULE__{
          date: Date.t(),
          type: String.t(),
          description: String.t(),
          metadata: map()
        }

  defimpl Beancount.Directive do
    def to_bean(%{date: date, type: type, description: description} = event) do
      header =
        Renderer.format_date(date) <>
          " event " <>
          Renderer.quote_string(type) <> " " <> Renderer.quote_string(description)

      Renderer.lines_to_fragment([header | Renderer.render_metadata(event.metadata)])
    end
  end
end
