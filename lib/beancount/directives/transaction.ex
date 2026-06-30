defmodule Beancount.Directives.Transaction do
  @moduledoc """
  The `transaction` directive records a balanced movement between accounts.

      2026-01-31 * "Employer" "Salary"
        Assets:Bank      5000 USD
        Income:Salary   -5000 USD

  A transaction carries a `flag` (`*` or `!`), an optional `payee`, a
  `narration`, a list of `postings`, plus optional `tags`, `links` and
  `metadata`.
  """

  alias Beancount.Renderer

  @enforce_keys [:date, :flag, :postings]
  defstruct date: nil,
            flag: "*",
            payee: nil,
            narration: "",
            postings: [],
            tags: [],
            links: [],
            metadata: %{}

  @type t :: %__MODULE__{
          date: Date.t(),
          flag: String.t(),
          payee: String.t() | nil,
          narration: String.t(),
          postings: [Beancount.Directives.Posting.t()],
          tags: [String.t()],
          links: [String.t()],
          metadata: map()
        }

  defimpl Beancount.Directive do
    def to_bean(txn) do
      header =
        Renderer.format_date(txn.date) <>
          " " <>
          txn.flag <>
          description(txn.payee, txn.narration) <>
          Renderer.render_tags_and_links(txn.tags, txn.links)

      lines =
        [header] ++
          Renderer.render_metadata(txn.metadata) ++
          Renderer.render_postings(txn.postings)

      Renderer.lines_to_fragment(lines)
    end

    defp description(nil, narration), do: " " <> Renderer.quote_string(narration)

    defp description(payee, narration) do
      " " <> Renderer.quote_string(payee) <> " " <> Renderer.quote_string(narration)
    end
  end
end
