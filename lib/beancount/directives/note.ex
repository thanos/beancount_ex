defmodule Beancount.Directives.Note do
  @moduledoc """
  The `note` directive attaches a dated comment to an account.

  See [Notes](https://beancount.github.io/docs/beancount_language_syntax/#notes).

  ## Beancount syntax

      2026-01-01 note Assets:Bank "Called the bank about fees"

  General form: `YYYY-MM-DD note Account "Comment"`

  ## Elixir struct

      %Beancount.Directives.Note{
        date: ~D[2026-01-01],
        account: "Assets:Bank",
        comment: "Called the bank about fees",
        metadata: %{}
      }

  Or use `Beancount.note/4`:

      Beancount.note(~D[2026-01-01], "Assets:Bank", "Called the bank about fees")

  ## Fields

    * `date` - `Date.t()` the note applies to.
    * `account` - account the comment is attached to.
    * `comment` - free-text string (rendered quoted).
    * `metadata` - optional map rendered below the directive.
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
