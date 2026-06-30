defmodule Beancount.Parser.Lexer do
  @moduledoc false

  import NimbleParsec

  digit = ascii_char([?0..?9])

  date =
    times(digit, 4)
    |> ignore(string("-"))
    |> concat(times(digit, 2))
    |> ignore(string("-"))
    |> concat(times(digit, 2))
    |> reduce({Enum, :join, [""]})
    |> reduce({Date, :from_iso8601, []})

  account_char = ascii_char([?A..?Z, ?a..?z, ?0..?9])

  account =
    ascii_char([?A..?Z])
    |> concat(
      repeat(
        choice([
          account_char,
          ignore(string(":"))
        ])
      )
    )
    |> reduce({Enum, :join, [""]})

  commodity =
    ascii_char([?A..?Z])
    |> concat(optional(ascii_string([?A..?Z, ?0..?9, ?_], min: 1)))
    |> reduce({Enum, :join, [""]})

  quoted_char =
    choice([
      ignore(string("\\\"")) |> replace("\""),
      ignore(string("\\\\")) |> replace("\\"),
      utf8_char([])
    ])

  quoted_string =
    ignore(string("\""))
    |> repeat(quoted_char)
    |> ignore(string("\""))
    |> reduce({Enum, :join, [""]})

  defparsec(:date, date)
  defparsec(:account, account)
  defparsec(:commodity, commodity)
  defparsec(:quoted_string, quoted_string)

  @doc false
  def parse_account(text) do
    case Regex.run(~r/^([A-Z][A-Za-z0-9]*(?::[A-Z][A-Za-z0-9]*)*)/, text) do
      [match, account] -> {:ok, account, String.slice(text, String.length(match)..-1//1)}
      _ -> account(text) |> unwrap()
    end
  end

  @doc false
  def parse_commodity(text) do
    case Regex.run(~r/^([A-Z][A-Z0-9_]*)/, text) do
      [match, commodity] -> {:ok, commodity, String.slice(text, String.length(match)..-1//1)}
      _ -> commodity(text) |> unwrap()
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
        quoted_string(text) |> unwrap()
    end
  end

  defp unescape_string(text) do
    text
    |> String.replace("\\\"", "\"")
    |> String.replace("\\\\", "\\")
  end

  defp unwrap({:ok, value, rest, _, _, _}), do: {:ok, value, rest}
  defp unwrap(other), do: other

  @doc false
  @spec split_tokens(binary()) :: [binary()]
  def split_tokens(text) do
    Regex.scan(~r/"([^"\\]|\\.)*"|\S+/, text)
    |> Enum.map(fn [token | _] -> token end)
  end
end
