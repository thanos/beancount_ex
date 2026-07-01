defmodule Beancount.Directives.Close do
  @moduledoc """
  The `close` directive marks an account as inactive.

  See the [Beancount Close directive](https://beancount.github.io/docs/beancount_language_syntax/#close).

  ## Beancount syntax

      2026-12-31 close Assets:Bank
        archived: TRUE

  General form: `YYYY-MM-DD close Account`

  ## Elixir struct

      %Beancount.Directives.Close{
        date: ~D[2026-12-31],
        account: "Assets:Bank",
        metadata: %{"archived" => true}
      }

  Or use `Beancount.close/3`:

      Beancount.close(~D[2026-12-31], "Assets:Bank",
        metadata: %{"archived" => true}
      )

  ## Fields

    * `date` - `Date.t()` after which postings to this account are invalid.
    * `account` - colon-separated account name being closed.
    * `metadata` - optional map of key/value pairs rendered below the directive.
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
