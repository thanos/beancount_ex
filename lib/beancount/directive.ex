defprotocol Beancount.Directive do
  @moduledoc """
  Protocol implemented by every Beancount directive struct.

  A directive knows how to render itself into a fragment of valid Beancount
  text via `to_bean/1`. The top-level `Beancount.Renderer` is responsible for
  joining individual directive fragments into a complete `.bean` document.

  ## Directive structs

  Each module under `Beancount.Directives` documents its Beancount syntax,
  Elixir struct shape, and fields. See the
  [Beancount language syntax](https://beancount.github.io/docs/beancount_language_syntax/#directives_1).

    * `Beancount.Directives.Open` — `open`
    * `Beancount.Directives.Close` — `close`
    * `Beancount.Directives.Commodity` — `commodity`
    * `Beancount.Directives.Transaction` — `*` / `txn` transactions
    * `Beancount.Directives.Posting` — transaction legs
    * `Beancount.Directives.Balance` — `balance`
    * `Beancount.Directives.Pad` — `pad`
    * `Beancount.Directives.Note` — `note`
    * `Beancount.Directives.Document` — `document`
    * `Beancount.Directives.Price` — `price`
    * `Beancount.Directives.Event` — `event`
    * `Beancount.Directives.Query` — `query`
    * `Beancount.Directives.Custom` — `custom`
    * `Beancount.Directives.Option` — `option`
    * `Beancount.Directives.Include` — `include`
    * `Beancount.Directives.Plugin` — `plugin`
    * `Beancount.Directives.PushTag` — `pushtag`
    * `Beancount.Directives.PopTag` — `poptag`

  Prefer `Beancount.open/4`, `Beancount.transaction/6`, and the other
  constructor functions in `Beancount` when building ledgers programmatically.
  """

  @typedoc "Any value implementing the `Beancount.Directive` protocol."
  @type t :: term()

  @doc """
  Render a single directive into Beancount text.

  The returned value is `t:iodata/0` without a trailing newline. The renderer
  takes care of separating directives.

  ## Examples

      iex> open = Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"])
      iex> open |> Beancount.Directive.to_bean() |> IO.iodata_to_binary()
      "2026-01-01 open Assets:Bank USD"

  """
  @spec to_bean(t()) :: iodata()
  def to_bean(directive)
end
