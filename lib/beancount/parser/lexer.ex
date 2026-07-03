defmodule Beancount.Parser.Lexer do
  @moduledoc false

  @doc false
  def parse_account(text) do
    case Regex.run(~r/^([A-Z][A-Za-z0-9-]*(?::[A-Z][A-Za-z0-9-]*)*)/, text) do
      [match, account] -> {:ok, account, String.slice(text, String.length(match)..-1//1)}
      _ -> {:error, false, text, 0, 1, []}
    end
  end

  @doc false
  def parse_commodity(text) do
    case Regex.run(~r/^([A-Z][A-Z0-9_]*)/, text) do
      [match, commodity] -> {:ok, commodity, String.slice(text, String.length(match)..-1//1)}
      _ -> {:error, false, text, 0, 1, []}
    end
  end

  @doc false
  def parse_number(text) do
    case Regex.run(~r/^(-?\d+(?:\.\d+)?)/, text) do
      [match, num] -> {:ok, Decimal.new(num), String.slice(text, String.length(match)..-1//1)}
      _ -> {:error, false, text, 0, 1, []}
    end
  end

  @doc false
  def parse_quoted_string(text) do
    case Regex.run(~r/^"((?:[^"\\]|\\.)*)"/, text) do
      [match, inner] ->
        {:ok, unescape_string(inner), String.slice(text, String.length(match)..-1//1)}

      _ ->
        {:error, false, text, 0, 1, []}
    end
  end

  defp unescape_string(text) do
    text
    |> String.replace("\\\"", "\"")
    |> String.replace("\\\\", "\\")
  end

  @doc false
  @spec split_tokens(binary()) :: [binary()]
  def split_tokens(text) do
    Regex.scan(~r/"([^"\\]|\\.)*"|\S+/, text)
    |> Enum.map(fn [token | _] -> token end)
  end
end
