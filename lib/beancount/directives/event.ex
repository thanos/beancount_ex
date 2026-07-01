defmodule Beancount.Directives.Event do
  @moduledoc """
  The `event` directive tracks the value of a named variable over time.

  See [Events](https://beancount.github.io/docs/beancount_language_syntax/#events).

  ## Beancount syntax

      2026-01-01 event "location" "New York"

  General form: `YYYY-MM-DD event "Type" "Description"`

  ## Elixir struct

      %Beancount.Directives.Event{
        date: ~D[2026-01-01],
        type: "location",
        description: "New York",
        metadata: %{}
      }

  Or use `Beancount.event/4`:

      Beancount.event(~D[2026-01-01], "location", "New York")

  ## Fields

    * `date` - `Date.t()` the event occurred.
    * `type` - event category name (e.g. `"location"`, `"employer"`).
    * `description` - new value or label for the event type.
    * `metadata` - optional map rendered below the directive.
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
