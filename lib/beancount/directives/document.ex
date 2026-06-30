defmodule Beancount.Directives.Document do
  @moduledoc """
  The `document` directive links a file to an account at a date.

      2026-01-01 document Assets:Bank "statements/2026-01.pdf"

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
