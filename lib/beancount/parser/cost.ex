defmodule Beancount.Parser.Cost do
  @moduledoc false

  alias Beancount.CostSpec
  alias Beancount.Parser.{Error, Lexer}

  @spec parse(binary(), keyword()) :: {:ok, CostSpec.t()} | {:error, Error.t()}
  def parse(text, opts \\ []) do
    text = String.trim(text)

    cond do
      String.starts_with?(text, "{{") and String.ends_with?(text, "}}") ->
        inner = String.slice(text, 2..-3//1)
        parse_total_only(inner, opts)

      String.starts_with?(text, "{") and String.ends_with?(text, "}") ->
        inner = String.slice(text, 1..-2//1)
        parse_braced(inner, opts)

      true ->
        error("invalid cost spec", opts)
    end
  end

  defp parse_total_only(inner, opts) do
    with {:ok, tokens} <- tokenize(inner, opts),
         {:ok, amount, currency, rest} <- parse_amount_currency(tokens, opts),
         :ok <- ensure_empty(rest, opts) do
      {:ok, %CostSpec{total_amount: amount, total_currency: currency, merge: false}}
    end
  end

  defp parse_braced(inner, opts) do
    with {:ok, tokens} <- tokenize(inner, opts) do
      parse_braced_tokens(tokens, opts)
    end
  end

  defp parse_braced_tokens([date | rest], opts) do
    if is_date_token?(date) do
      with {:ok, date} <- parse_date_token(date, opts),
           {:ok, _extras, merge} <- parse_extras(rest, opts) do
        {:ok, %CostSpec{date: date, merge: merge}}
      end
    else
      parse_braced_tokens_label_or_amount([date | rest], opts)
    end
  end

  defp parse_braced_tokens_label_or_amount([label | rest], opts) do
    if is_quoted?(label) do
      with {:ok, label} <- parse_quoted(label, opts),
           {:ok, _extras, merge} <- parse_extras(rest, opts) do
        {:ok, %CostSpec{label: label, merge: merge}}
      end
    else
      parse_braced_amount([label | rest], opts)
    end
  end

  defp parse_braced_amount(tokens, opts) do
    with {:ok, per_amount, per_currency, rest} <- parse_amount_currency(tokens, opts) do
      case rest do
        ["#", amount, currency | extras] ->
          with {:ok, total_amount} <- parse_number_token(amount, opts),
               {:ok, total_currency} <- parse_commodity_token(currency, opts),
               {:ok, _extras, merge} <- parse_extras(extras, opts) do
            {:ok,
             %CostSpec{
               per_amount: per_amount,
               per_currency: per_currency,
               total_amount: total_amount,
               total_currency: total_currency,
               merge: merge
             }}
          end

        rest ->
          with {:ok, date, label, merge} <- parse_per_extras(rest, opts) do
            {:ok,
             %CostSpec{
               per_amount: per_amount,
               per_currency: per_currency,
               date: date,
               label: label,
               merge: merge
             }}
          end
      end
    end
  end

  defp parse_per_extras(tokens, opts) do
    {date, label, merge, rest} = split_extras(tokens, opts)

    case rest do
      [] -> {:ok, date, label, merge}
      _ -> error("unexpected tokens in cost spec", opts)
    end
  end

  defp parse_extras(tokens, opts) do
    {date, label, merge, rest} = split_extras(tokens, opts)

    case rest do
      [] -> {:ok, {date, label}, merge}
      _ -> error("unexpected tokens in cost spec", opts)
    end
  end

  defp split_extras(tokens, opts) do
    {date, rest} =
      case tokens do
        [token | rest] ->
          if is_date_token?(token) do
            {:ok, date} = parse_date_token(token, opts)
            {date, rest}
          else
            {nil, tokens}
          end

        _ ->
          {nil, tokens}
      end

    {label, rest} =
      case rest do
        [token | rest] ->
          if is_quoted?(token) do
            {:ok, label} = parse_quoted(token, opts)
            {label, rest}
          else
            {nil, rest}
          end

        _ ->
          {nil, rest}
      end

    {merge, rest} =
      case rest do
        ["merge" | rest] -> {true, rest}
        _ -> {false, rest}
      end

    {date, label, merge, rest}
  end

  defp parse_amount_currency([amount, currency | rest], opts) do
    with {:ok, amount} <- parse_number_token(amount, opts),
         {:ok, currency} <- parse_commodity_token(currency, opts) do
      {:ok, amount, currency, rest}
    end
  end

  defp parse_amount_currency(_tokens, opts), do: error("expected amount and currency", opts)

  defp tokenize(inner, opts) do
    parts =
      inner
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.flat_map(&Lexer.split_tokens/1)

    if parts == [] do
      error("empty cost spec", opts)
    else
      {:ok, parts}
    end
  end

  defp ensure_empty([], _opts), do: :ok
  defp ensure_empty(_rest, opts), do: error("unexpected tokens in cost spec", opts)

  defp is_date_token?(token), do: Regex.match?(~r/^\d{4}-\d{2}-\d{2}$/, token)
  defp is_quoted?(token), do: String.starts_with?(token, "\"") and String.ends_with?(token, "\"")

  defp parse_date_token(token, _opts), do: Date.from_iso8601(token)
  defp parse_number_token(token, opts), do: Lexer.parse_number(token) |> map_error(opts)
  defp parse_commodity_token(token, opts), do: Lexer.parse_commodity(token) |> map_error(opts)

  defp parse_quoted(token, opts) do
    case Lexer.parse_quoted_string(token) do
      {:ok, value, ""} -> {:ok, value}
      _ -> error("invalid quoted string in cost spec", opts)
    end
  end

  defp map_error({:ok, value, ""}, _opts), do: {:ok, value}
  defp map_error(_, opts), do: error("invalid token in cost spec", opts)

  defp error(message, opts) do
    {:error,
     %Error{message: message, line: Keyword.get(opts, :line), column: Keyword.get(opts, :column)}}
  end
end
