defmodule Beancount.Directives.Query do
  @moduledoc """
  The `query` directive stores a named BQL query in the ledger.

  See [Query](https://beancount.github.io/docs/beancount_language_syntax/#query).

  ## Beancount syntax

      2026-01-01 query "monthly" "SELECT account, sum(position) GROUP BY account"

  General form: `YYYY-MM-DD query "Name" "BQL"`

  ## Elixir struct

      %Beancount.Directives.Query{
        date: ~D[2026-01-01],
        name: "monthly",
        bql: "SELECT account, sum(position) GROUP BY account",
        metadata: %{}
      }

  Or use `Beancount.query_directive/4`:

      Beancount.query_directive(~D[2026-01-01], "monthly",
        "SELECT account, sum(position) GROUP BY account"
      )

  ## Fields

    * `date` - `Date.t()` the query definition is recorded.
    * `name` - unique identifier for the saved query.
    * `bql` - Beancount Query Language string.
    * `metadata` - optional map rendered below the directive.
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
