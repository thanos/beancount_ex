defmodule Beancount.Directives.Document do
  @moduledoc """
  The `document` directive links a file to an account at a date.

  See [Documents](https://beancount.github.io/docs/beancount_language_syntax/#documents).

  ## Beancount syntax

      2026-01-01 document Assets:Bank "statements/2026-01.pdf"

  General form: `YYYY-MM-DD document Account "Path"`

  ## Elixir struct

      %Beancount.Directives.Document{
        date: ~D[2026-01-01],
        account: "Assets:Bank",
        path: "statements/2026-01.pdf",
        metadata: %{}
      }

  Or use `Beancount.document/4`:

      Beancount.document(~D[2026-01-01], "Assets:Bank", "statements/2026-01.pdf")

  ## Fields

    * `date` - `Date.t()` the document is associated with.
    * `account` - account the file belongs to (often Assets or Liabilities).
    * `path` - relative or absolute file path string.
    * `metadata` - optional map rendered below the directive.
  """

  alias Beancount.Renderer

  @enforce_keys [:date, :account, :path]
  defstruct date: nil, account: nil, path: nil, metadata: %{}

  @type t :: %__MODULE__{
          date: Date.t(),
          account: String.t(),
          path: String.t(),
          metadata: map()
        }

  defimpl Beancount.Directive do
    def to_bean(%{date: date, account: account, path: path} = document) do
      header =
        Renderer.format_date(date) <>
          " document " <> account <> " " <> Renderer.quote_string(path)

      Renderer.lines_to_fragment([header | Renderer.render_metadata(document.metadata)])
    end
  end
end
