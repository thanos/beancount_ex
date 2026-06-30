defmodule Beancount.Directives.Note do
  @moduledoc """
  The `note` directive attaches a dated comment to an account.

      2026-01-01 note Assets:Bank "Called the bank about fees"

  """

  alias Beancount.Renderer

  @enforce_keys [:date, :account, :comment]
  defstruct date: nil, account: nil, comment: nil, metadata: %{}

  @type t :: %__MODULE__{
          date: Date.t(),
          account: String.t(),
          comment: String.t(),
          metadata: map()
        }

  defimpl Beancount.Directive do
    def to_bean(%{date: date, account: account, comment: comment} = note) do
      header =
        Renderer.format_date(date) <>
          " note " <> account <> " " <> Renderer.quote_string(comment)

      Renderer.lines_to_fragment([header | Renderer.render_metadata(note.metadata)])
    end
  end
end
