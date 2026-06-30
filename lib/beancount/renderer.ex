defmodule Beancount.Renderer do
  @moduledoc """
  Deterministic rendering of directive streams into Beancount text.

  Rendering is intentionally pure and deterministic: rendering the same
  directive stream twice always produces byte-identical output. This property
  is essential for golden-file regression testing and for using Beancount as a
  behavioral oracle.

  The module also exposes the low-level formatting helpers
  (`format_date/1`, `format_decimal/1`, `quote_string/1`, ...) used by the
  individual `Beancount.Directive` implementations.
  """

  alias Beancount.{CostSpec, Directive, Value}

  @indent "  "

  @doc """
  Render a list of directives into a complete `.bean` document.

  Directives are separated by a single blank line and the document ends with a
  trailing newline.

  ## Examples

      iex> ledger = [
      ...>   Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
      ...>   Beancount.close(~D[2026-12-31], "Assets:Bank")
      ...> ]
      iex> Beancount.Renderer.render(ledger)
      "2026-01-01 open Assets:Bank USD\\n\\n2026-12-31 close Assets:Bank\\n"

  """
  @spec render([Directive.t()]) :: binary()
  def render(directives) when is_list(directives) do
    body =
      directives
      |> Enum.map(&Directive.to_bean/1)
      |> Enum.map_join("\n\n", &IO.iodata_to_binary/1)

    case body do
      "" -> ""
      text -> text <> "\n"
    end
  end

  @doc """
  Format a `Date` as an ISO-8601 `YYYY-MM-DD` string.

  ## Examples

      iex> Beancount.Renderer.format_date(~D[2026-01-31])
      "2026-01-31"

  """
  @spec format_date(Date.t()) :: binary()
  def format_date(%Date{} = date), do: Date.to_iso8601(date)

  @doc """
  Format a `Decimal` using plain (non-scientific) notation.

  ## Examples

      iex> Beancount.Renderer.format_decimal(Decimal.new("-5000"))
      "-5000"

      iex> Beancount.Renderer.format_decimal(Decimal.new("12.50"))
      "12.50"

  """
  @spec format_decimal(Decimal.t()) :: binary()
  def format_decimal(%Decimal{} = decimal), do: Decimal.to_string(decimal, :normal)

  @doc """
  Quote and escape a string the way Beancount expects.

  ## Examples

      iex> Beancount.Renderer.quote_string(~S(a "quoted" value))
      ~S("a \\"quoted\\" value")

  """
  @spec quote_string(binary()) :: binary()
  def quote_string(string) when is_binary(string) do
    escaped =
      string
      |> String.replace("\\", "\\\\")
      |> String.replace("\"", "\\\"")

    "\"" <> escaped <> "\""
  end

  @doc """
  Render a scalar value as used in metadata and `custom` directives.

  - binaries become quoted strings
  - `Decimal` and numbers become bare numbers
  - `Date` becomes an ISO date
  - booleans become `TRUE`/`FALSE`
  - atoms become barewords (useful for accounts/currencies)
  - `Beancount.Value.Account`, `Tag`, and `Amount` for custom directives
  """
  @spec format_value(term()) :: binary()
  def format_value(%Value.Account{name: name}), do: name
  def format_value(%Value.Tag{name: name}), do: "#" <> name

  def format_value(%Value.Amount{number: %Decimal{} = number, currency: currency}) do
    format_decimal(number) <> " " <> currency
  end

  def format_value(value) when is_binary(value), do: quote_string(value)
  def format_value(%Decimal{} = value), do: format_decimal(value)
  def format_value(%Date{} = value), do: format_date(value)
  def format_value(true), do: "TRUE"
  def format_value(false), do: "FALSE"
  def format_value(value) when is_integer(value), do: Integer.to_string(value)
  def format_value(value) when is_atom(value), do: Atom.to_string(value)

  def format_value(value) when is_float(value) do
    value |> Decimal.from_float() |> format_decimal()
  end

  @doc """
  Render a metadata map into indented `key: value` lines.

  Keys are emitted in deterministic (sorted) order. Returns an empty list when
  there is no metadata.
  """
  @spec render_metadata(map(), non_neg_integer()) :: [binary()]
  def render_metadata(metadata, depth \\ 1)

  def render_metadata(metadata, _depth) when metadata == %{}, do: []

  def render_metadata(metadata, depth) when is_map(metadata) do
    indent = String.duplicate(@indent, depth)

    metadata
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.map(fn {key, value} ->
      indent <> to_string(key) <> ": " <> format_value(value)
    end)
  end

  @doc """
  Render `#tag` and `^link` suffixes for a transaction header.

  Tags are rendered before links, each in sorted order for determinism.
  """
  @spec render_tags_and_links([binary()], [binary()]) :: binary()
  def render_tags_and_links(tags, links) do
    tag_part = tags |> Enum.sort() |> Enum.map_join("", &(" #" <> &1))
    link_part = links |> Enum.sort() |> Enum.map_join("", &(" ^" <> &1))
    tag_part <> link_part
  end

  @doc """
  Render the postings of a transaction as aligned, indented lines.

  Amounts are right-aligned so that decimal values line up, matching the
  conventional Beancount layout. Posting-level metadata is rendered indented
  beneath its posting.
  """
  @spec render_postings([Beancount.Directives.Posting.t()]) :: [binary()]
  def render_postings(postings) do
    target = posting_amount_column(postings)

    Enum.flat_map(postings, fn posting ->
      [render_posting_line(posting, target) | render_metadata(posting.metadata, 2)]
    end)
  end

  defp posting_amount_column(postings) do
    postings
    |> Enum.map(&posting_column_width/1)
    |> Enum.max(fn -> 0 end)
  end

  defp posting_column_width(posting) do
    prefix_len = String.length(posting_prefix(posting))

    cond do
      has_amount?(posting) ->
        prefix_len + 2 + String.length(posting_number(posting))

      commodity_price?(posting) ->
        prefix_len + 2 + String.length(posting.currency) +
          String.length(cost_suffix(posting) <> price_suffix(posting))

      true ->
        prefix_len
    end
  end

  defp render_posting_line(posting, target) do
    prefix = posting_prefix(posting)

    cond do
      has_amount?(posting) ->
        number = posting_number(posting)
        pad = max(target - String.length(prefix) - String.length(number), 2)
        tail = posting_amount_tail(posting)
        prefix <> String.duplicate(" ", pad) <> number <> tail

      commodity_price?(posting) ->
        commodity = posting.currency
        pad = max(target - String.length(prefix) - String.length(commodity), 2)
        tail = cost_suffix(posting) <> price_suffix(posting)
        prefix <> String.duplicate(" ", pad) <> commodity <> tail

      true ->
        prefix
    end
  end

  defp commodity_price?(%{amount: nil, currency: currency, price: %{amount: %Decimal{}}})
       when is_binary(currency),
       do: true

  defp commodity_price?(_), do: false

  defp posting_amount_tail(%{currency: currency} = posting) when is_binary(currency) do
    " " <> currency <> cost_suffix(posting) <> price_suffix(posting)
  end

  defp posting_amount_tail(posting) do
    cost_suffix(posting) <> price_suffix(posting)
  end

  defp posting_prefix(posting) do
    flag = if posting.flag, do: posting.flag <> " ", else: ""
    @indent <> flag <> posting.account
  end

  defp posting_number(%{amount: %Decimal{} = amount}), do: format_decimal(amount)

  defp has_amount?(%{amount: %Decimal{}}), do: true
  defp has_amount?(_posting), do: false

  defp cost_suffix(%{cost: nil}), do: ""

  defp cost_suffix(%{cost: cost}) do
    cost |> CostSpec.normalize() |> CostSpec.to_string() |> then(&(" " <> &1))
  end

  defp price_suffix(%{price: nil}), do: ""

  defp price_suffix(%{price: %{amount: %Decimal{} = amount, currency: currency, type: :total}}) do
    " @@ " <> format_decimal(amount) <> " " <> currency
  end

  defp price_suffix(%{price: %{amount: %Decimal{} = amount, currency: currency}}) do
    " @ " <> format_decimal(amount) <> " " <> currency
  end

  @doc """
  Join header text, metadata lines and body lines into a single fragment.

  Used by directives that span multiple lines (such as transactions).
  """
  @spec lines_to_fragment([binary()]) :: binary()
  def lines_to_fragment(lines), do: Enum.join(lines, "\n")
end
