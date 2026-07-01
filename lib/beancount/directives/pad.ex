defmodule Beancount.Directives.Pad do
  @moduledoc """
  The `pad` directive inserts an automatic balancing transaction before the next
  balance assertion on an account.

  See [Pad](https://beancount.github.io/docs/beancount_language_syntax/#pad).

  ## Beancount syntax

      2025-12-20 pad Assets:Cash Equity:Opening

  General form: `YYYY-MM-DD pad Account SourceAccount`

  Beancount generates a transaction between `account` and `source_account` so the
  next `balance` on `account` can succeed.

  ## Elixir struct

      %Beancount.Directives.Pad{
        date: ~D[2025-12-20],
        account: "Assets:Cash",
        source_account: "Equity:Opening",
        metadata: %{}
      }

  Or use `Beancount.pad/4`:

      Beancount.pad(~D[2025-12-20], "Assets:Cash", "Equity:Opening")

  ## Fields

    * `date` - `Date.t()` from which the pad is active until the next balance on
      `account`.
    * `account` - account to pad (must later have a `balance` directive).
    * `source_account` - offset account for the generated padding transaction.
    * `metadata` - optional map rendered below the directive.
  """

  alias Beancount.Renderer

  @enforce_keys [:date, :account, :source_account]
  defstruct date: nil, account: nil, source_account: nil, metadata: %{}

  @type t :: %__MODULE__{
          date: Date.t(),
          account: String.t(),
          source_account: String.t(),
          metadata: map()
        }

  defimpl Beancount.Directive do
    def to_bean(%{date: date, account: account, source_account: source} = pad) do
      header =
        Renderer.format_date(date) <>
          " pad " <> account <> " " <> source

      Renderer.lines_to_fragment([header | Renderer.render_metadata(pad.metadata)])
    end
  end
end
