defmodule Beancount.Parser.Posting do
  @moduledoc false

  alias Beancount.Directives.Posting
  alias Beancount.Parser.{Cost, Error, Lexer}

  @spec parse_line(binary(), keyword()) :: {:ok, Posting.t()} | {:error, Error.t()}
  def parse_line(line, opts \\ []) do
    line = String.trim_leading(line)

    with {:ok, flag, rest} <- parse_flag(line, opts),
         {:ok, account, rest} <- parse_account(rest, opts),
         {:ok, amount, currency, rest} <- parse_amount_currency(rest, opts),
         {:ok, cost, rest} <- parse_optional_cost(rest, opts),
         {:ok, price, rest} <- parse_optional_price(rest, opts),
         :ok <- ensure_end(rest, opts) do
      {:ok,
       %Posting{
         account: account,
         amount: amount,
         currency: currency,
         cost: cost,
         price: price,
         flag: flag,
         metadata: %{}
       }}
    end
  end

  defp parse_flag(line, _opts) do
    case line do
      "!" <> rest -> {:ok, "!", String.trim_leading(rest)}
      "?" <> rest -> {:ok, "?", String.trim_leading(rest)}
      _ -> {:ok, nil, line}
    end
  end

  defp parse_account(line, opts) do
    tokens = Lexer.split_tokens(String.trim(line))

    case tokens do
      [account | rest] ->
        case Lexer.parse_account(account) do
          {:ok, _, ""} -> {:ok, account, Enum.join(rest, " ")}
          _ -> error("invalid posting account", opts)
        end

      _ ->
        error("expected posting account", opts)
    end
  end

  defp parse_amount_currency(rest, opts) do
    rest = String.trim(rest)

    if rest == "" do
      {:ok, nil, nil, ""}
    else
      tokens = Lexer.split_tokens(rest)

      case tokens do
        [number | tail] ->
          case Lexer.parse_number(number) do
            {:ok, amount, ""} ->
              case tail do
                [currency | rest] ->
                  case Lexer.parse_commodity(currency) do
                    {:ok, _, ""} ->
                      {:ok, amount, currency, Enum.join(rest, " ")}

                    _ ->
                      {:ok, amount, nil, Enum.join(tail, " ")}
                  end

                [] ->
                  {:ok, amount, nil, ""}
              end

            _ ->
              parse_commodity_price(tokens, opts)
          end

        _ ->
          parse_commodity_price(tokens, opts)
      end
    end
  end

  defp parse_commodity_price(tokens, opts) do
    case tokens do
      [currency | tail] ->
        with {:ok, currency} <- unwrap_lexer(Lexer.parse_commodity(currency), opts) do
          {:ok, nil, currency, Enum.join(tail, " ")}
        end

      _ ->
        error("invalid posting amount", opts)
    end
  end

  defp parse_optional_cost("", _opts), do: {:ok, nil, ""}

  defp parse_optional_cost(rest, opts) do
    rest = String.trim_leading(rest)

    if String.starts_with?(rest, "{") do
      case extract_braced(rest) do
        {:ok, braced, tail} ->
          with {:ok, cost} <- Cost.parse(braced, opts) do
            {:ok, cost, String.trim_leading(tail)}
          end

        :error ->
          error("unclosed cost spec", opts)
      end
    else
      {:ok, nil, rest}
    end
  end

  defp parse_optional_price("", _opts), do: {:ok, nil, ""}

  defp parse_optional_price(rest, opts) do
    rest = String.trim_leading(rest)

    cond do
      String.starts_with?(rest, "@@") ->
        with {:ok, price, tail} <-
               parse_price_amount(String.trim_leading(String.slice(rest, 2..-1//1)), :total, opts) do
          {:ok, price, tail}
        end

      String.starts_with?(rest, "@") ->
        with {:ok, price, tail} <-
               parse_price_amount(String.trim_leading(String.slice(rest, 1..-1//1)), :unit, opts) do
          {:ok, price, tail}
        end

      true ->
        {:ok, nil, rest}
    end
  end

  defp parse_price_amount(rest, type, opts) do
    tokens = Lexer.split_tokens(String.trim(rest))

    case tokens do
      [number, currency | tail] ->
        with {:ok, amount} <- Lexer.parse_number(number) |> unwrap_lexer(opts),
             {:ok, currency} <- Lexer.parse_commodity(currency) |> unwrap_lexer(opts) do
          {:ok, %{amount: amount, currency: currency, type: type}, Enum.join(tail, " ")}
        end

      _ ->
        error("invalid price annotation", opts)
    end
  end

  defp extract_braced(text) do
    case Regex.run(~r/^(\{\{.*?\}\}|\{.*?\})/, text, capture: :all_but_first) do
      [match] -> {:ok, match, String.slice(text, String.length(match)..-1//1)}
      _ -> :error
    end
  end

  defp ensure_end("", _opts), do: :ok
  defp ensure_end(_rest, opts), do: error("unexpected trailing posting tokens", opts)

  defp unwrap_lexer({:ok, value, ""}, _opts), do: {:ok, value}
  defp unwrap_lexer(_, opts), do: error("invalid posting token", opts)

  defp error(message, opts) do
    {:error,
     %Error{message: message, line: Keyword.get(opts, :line), column: Keyword.get(opts, :column)}}
  end
end
