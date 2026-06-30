defmodule Beancount.Parser.Metadata do
  @moduledoc false

  alias Beancount.Parser.{Error, Lexer}
  alias Beancount.Value

  @spec parse_line(binary(), keyword()) :: {:ok, {binary(), term()}} | {:error, Error.t()}
  def parse_line(line, opts \\ []) do
    line = String.trim_leading(line)

    case String.split(line, ":", parts: 2) do
      [key, value] ->
        key = String.trim(key)

        with {:ok, parsed} <- parse_value(String.trim(value), opts) do
          {:ok, {key, parsed}}
        end

      _ ->
        error("invalid metadata line", opts)
    end
  end

  @spec parse_value(binary(), keyword()) :: {:ok, term()} | {:error, Error.t()}
  def parse_value(text, opts \\ []) do
    text = String.trim(text)

    cond do
      text == "TRUE" ->
        {:ok, true}

      text == "FALSE" ->
        {:ok, false}

      String.starts_with?(text, "\"") ->
        parse_quoted(text, opts)

      String.starts_with?(text, "#") ->
        {:ok, %Value.Tag{name: String.slice(text, 1..-1//1)}}

      Regex.match?(~r/^\d{4}-\d{2}-\d{2}$/, text) ->
        Date.from_iso8601(text)

      match?({:ok, _, ""}, Lexer.parse_number(text)) ->
        Lexer.parse_number(text) |> unwrap_lexer(opts)

      amount_currency?(text) ->
        parse_amount(text, opts)

      true ->
        {:ok, text}
    end
  end

  defp parse_quoted(text, opts) do
    case Lexer.parse_quoted_string(text) do
      {:ok, value, ""} -> {:ok, value}
      _ -> error("invalid quoted metadata value", opts)
    end
  end

  defp amount_currency?(text) do
    case Lexer.split_tokens(text) do
      [_amount, _currency | _] -> true
      _ -> false
    end
  end

  defp parse_amount(text, opts) do
    case Lexer.split_tokens(text) do
      [amount, currency | _] ->
        with {:ok, number} <- Lexer.parse_number(amount) |> unwrap_lexer(opts),
             {:ok, currency} <- Lexer.parse_commodity(currency) |> unwrap_lexer(opts) do
          {:ok, %Value.Amount{number: number, currency: currency}}
        end

      _ ->
        error("invalid amount metadata value", opts)
    end
  end

  defp unwrap_lexer({:ok, value, ""}, _opts), do: {:ok, value}
  defp unwrap_lexer(_, opts), do: error("invalid numeric metadata value", opts)

  defp error(message, opts) do
    {:error,
     %Error{message: message, line: Keyword.get(opts, :line), column: Keyword.get(opts, :column)}}
  end
end
