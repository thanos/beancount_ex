defmodule Beancount.Directives.Close do
  @moduledoc """
  The `close` directive marks an account as closed.

      2026-12-31 close Assets:Bank

  """

  alias Beancount.Renderer

  @enforce_keys [:date, :account]
  defstruct date: nil, account: nil, metadata: %{}

  @type t :: %__MODULE__{
          date: Date.t(),
          account: String.t(),
          metadata: map()
        }

  defimpl Beancount.Directive do
    def to_bean(%{date: date, account: account, metadata: metadata}) do
      header = Renderer.format_date(date) <> " close " <> account
      Renderer.lines_to_fragment([header | Renderer.render_metadata(metadata)])
    end
  end
end
