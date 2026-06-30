defmodule Beancount.Parser.Grammar do
  @moduledoc false

  alias Beancount.Directives.{
    Balance,
    Close,
    Commodity,
    Custom,
    Document,
    Event,
    Include,
    Note,
    Open,
    Option,
    Pad,
    Plugin,
    PopTag,
    Price,
    PushTag,
    Query,
    Transaction
  }

  alias Beancount.Parser.{Error, Lexer, Metadata, Posting}
  alias Beancount.Value

  @date_regex ~r/^(\d{4}-\d{2}-\d{2})\s+/

  @spec parse(binary()) :: {:ok, [Beancount.Directive.t()]} | {:error, Error.t()}
  def parse(text) do
    lines = split_lines(text)

    case parse_lines(lines, 1, []) do
      {:ok, directives} -> {:ok, Enum.reverse(directives)}
      {:error, _} = error -> error
    end
  end

  defp split_lines(text) do
    text
    |> String.replace("\r\n", "\n")
    |> String.split("\n")
  end

  defp parse_lines([], _line_no, acc), do: {:ok, acc}

  defp parse_lines([line | rest], line_no, acc) do
    line = String.trim_trailing(line)

    cond do
      line == "" or String.starts_with?(line, ";") ->
        parse_lines(rest, line_no + 1, acc)

      undated_directive?(line) ->
        with {:ok, directive, rest, next_line} <- parse_undated(line, rest, line_no),
             {:ok, acc} <- parse_lines(rest, next_line, [directive | acc]) do
          {:ok, acc}
        end

      Regex.match?(@date_regex, line) ->
        with {:ok, directive, rest, next_line} <- parse_dated(line, rest, line_no),
             {:ok, acc} <- parse_lines(rest, next_line, [directive | acc]) do
          {:ok, acc}
        end

      true ->
        {:error, error("expected directive", line_no, 1)}
    end
  end

  defp undated_directive?(line) do
    String.starts_with?(line, "include ") or
      String.starts_with?(line, "option ") or
      String.starts_with?(line, "plugin ") or
      String.starts_with?(line, "pushtag ") or
      String.starts_with?(line, "poptag ")
  end

  defp parse_undated(line, rest, line_no) do
    opts = [line: line_no]

    cond do
      String.starts_with?(line, "include ") ->
        with {:ok, path} <- parse_quoted_rest(String.slice(line, 8..-1//1), opts) do
          {:ok, %Include{path: path}, rest, line_no + 1}
        end

      String.starts_with?(line, "option ") ->
        with {:ok, name, value} <- parse_option(String.slice(line, 7..-1//1), opts) do
          {:ok, %Option{name: name, value: value}, rest, line_no + 1}
        end

      String.starts_with?(line, "plugin ") ->
        with {:ok, plugin} <- parse_plugin(String.slice(line, 7..-1//1), opts) do
          {:ok, plugin, rest, line_no + 1}
        end

      String.starts_with?(line, "pushtag ") ->
        with {:ok, tag} <- parse_tag(String.slice(line, 8..-1//1), opts) do
          {:ok, %PushTag{tag: tag}, rest, line_no + 1}
        end

      String.starts_with?(line, "poptag ") ->
        with {:ok, tag} <- parse_tag(String.slice(line, 7..-1//1), opts) do
          {:ok, %PopTag{tag: tag}, rest, line_no + 1}
        end
    end
  end

  defp parse_dated(line, rest, line_no) do
    case Regex.run(@date_regex, line) do
      [_, date_text] ->
        {:ok, date} = Date.from_iso8601(date_text)
        remainder = line |> String.replace_prefix(date_text, "") |> String.trim_leading()
        parse_dated_body(date, remainder, rest, line_no)

      _ ->
        {:error, error("expected dated directive", line_no, 1)}
    end
  end

  defp parse_dated_body(date, remainder, rest, line_no) do
    opts = [line: line_no]

    case String.split(remainder, " ", parts: 2) do
      ["open", rest_line] ->
        with {:ok, open, rest, next_line} <- parse_open(date, rest_line, rest, line_no, opts) do
          {:ok, open, rest, next_line}
        end

      ["close", account] ->
        with {:ok, close, rest, next_line} <- parse_close(date, account, rest, line_no, opts) do
          {:ok, close, rest, next_line}
        end

      ["commodity", currency] ->
        with {:ok, commodity, rest, next_line} <-
               parse_simple_metadata(
                 date,
                 currency,
                 rest,
                 line_no,
                 fn date, currency, metadata ->
                   %Commodity{date: date, currency: currency, metadata: metadata}
                 end,
                 opts
               ) do
          {:ok, commodity, rest, next_line}
        end

      ["balance", rest_line] ->
        with {:ok, balance, rest, next_line} <-
               parse_balance(date, rest_line, rest, line_no, opts) do
          {:ok, balance, rest, next_line}
        end

      ["price", rest_line] ->
        with {:ok, price, rest, next_line} <- parse_price(date, rest_line, rest, line_no, opts) do
          {:ok, price, rest, next_line}
        end

      ["note", rest_line] ->
        with {:ok, note, rest, next_line} <- parse_note(date, rest_line, rest, line_no, opts) do
          {:ok, note, rest, next_line}
        end

      ["document", rest_line] ->
        with {:ok, document, rest, next_line} <-
               parse_document(date, rest_line, rest, line_no, opts) do
          {:ok, document, rest, next_line}
        end

      ["event", rest_line] ->
        with {:ok, event, rest, next_line} <- parse_event(date, rest_line, rest, line_no, opts) do
          {:ok, event, rest, next_line}
        end

      ["custom", rest_line] ->
        with {:ok, custom, rest, next_line} <- parse_custom(date, rest_line, rest, line_no, opts) do
          {:ok, custom, rest, next_line}
        end

      ["pad", rest_line] ->
        with {:ok, pad, rest, next_line} <- parse_pad(date, rest_line, rest, line_no, opts) do
          {:ok, pad, rest, next_line}
        end

      ["query", rest_line] ->
        with {:ok, query, rest, next_line} <- parse_query(date, rest_line, rest, line_no, opts) do
          {:ok, query, rest, next_line}
        end

      [flag, rest_line] ->
        with {:ok, txn, rest, next_line} <-
               parse_transaction(date, flag, rest_line, rest, line_no, opts) do
          {:ok, txn, rest, next_line}
        end

      _ ->
        {:error, error("unknown dated directive", line_no, 1)}
    end
  end

  defp parse_open(date, rest_line, rest, line_no, opts) do
    case Lexer.split_tokens(rest_line) do
      [account | tail] ->
        {metadata_lines, rest, next_line} = collect_metadata_lines(rest, line_no)

        with {:ok, account} <- parse_account_token(account, opts),
             {:ok, currencies, booking} <- parse_open_tail(tail, opts),
             {:ok, metadata} <- parse_metadata(metadata_lines, opts) do
          {:ok,
           %Open{
             date: date,
             account: account,
             currencies: currencies,
             booking: booking,
             metadata: metadata
           }, rest, next_line}
        end

      _ ->
        {:error, error("invalid open directive", line_no, 1)}
    end
  end

  defp parse_open_tail([], _opts), do: {:ok, [], nil}

  defp parse_open_tail([currencies], _opts) do
    {:ok, String.split(currencies, ",", trim: true), nil}
  end

  defp parse_open_tail([currencies, booking], opts) do
    with {:ok, booking} <- parse_quoted_token(booking, opts) do
      {:ok, String.split(currencies, ",", trim: true), booking}
    end
  end

  defp parse_open_tail(_tokens, opts),
    do: {:error, error("invalid open directive", opts[:line], 1)}

  defp parse_close(date, account, rest, line_no, opts) do
    {metadata_lines, rest, next_line} = collect_metadata_lines(rest, line_no)

    with {:ok, account} <- parse_account_token(account, opts),
         {:ok, metadata} <- parse_metadata(metadata_lines, opts) do
      {:ok, %Close{date: date, account: account, metadata: metadata}, rest, next_line}
    end
  end

  defp parse_simple_metadata(date, token, rest, line_no, builder, opts) do
    case Lexer.split_tokens(token) do
      [value | _] ->
        {metadata_lines, rest, next_line} = collect_metadata_lines(rest, line_no)

        with {:ok, value} <- parse_commodity_token(value, opts),
             {:ok, metadata} <- parse_metadata(metadata_lines, opts) do
          {:ok, builder.(date, value, metadata), rest, next_line}
        end

      _ ->
        {:error, error("invalid directive", line_no, 1)}
    end
  end

  defp parse_balance(date, rest_line, rest, line_no, opts) do
    case Lexer.split_tokens(rest_line) do
      [account | amount_tokens] ->
        {metadata_lines, rest, next_line} = collect_metadata_lines(rest, line_no)

        with {:ok, account} <- parse_account_token(account, opts),
             {:ok, amount, currency, tolerance} <- parse_balance_amount(amount_tokens, opts),
             {:ok, metadata} <- parse_metadata(metadata_lines, opts) do
          {:ok,
           %Balance{
             date: date,
             account: account,
             amount: amount,
             currency: currency,
             tolerance: tolerance,
             metadata: metadata
           }, rest, next_line}
        end

      _ ->
        {:error, error("invalid balance directive", line_no, 1)}
    end
  end

  defp parse_balance_amount(tokens, opts) do
    case tokens do
      [amount, "~", tolerance, currency] ->
        with {:ok, amount} <- parse_number_token(amount, opts),
             {:ok, tolerance} <- parse_number_token(tolerance, opts),
             {:ok, currency} <- parse_commodity_token(currency, opts) do
          {:ok, amount, currency, tolerance}
        end

      [amount, currency] ->
        with {:ok, amount} <- parse_number_token(amount, opts),
             {:ok, currency} <- parse_commodity_token(currency, opts) do
          {:ok, amount, currency, nil}
        end

      _ ->
        {:error, error("invalid balance amount", opts[:line], 1)}
    end
  end

  defp parse_price(date, rest_line, rest, line_no, opts) do
    tokens = Lexer.split_tokens(rest_line)

    case tokens do
      [currency, amount, quote_currency | _] ->
        with {:ok, currency} <- parse_commodity_token(currency, opts),
             {:ok, amount} <- parse_number_token(amount, opts),
             {:ok, quote_currency} <- parse_commodity_token(quote_currency, opts) do
          {metadata_lines, rest, next_line} = collect_metadata_lines(rest, line_no)

          with {:ok, metadata} <- parse_metadata(metadata_lines, opts) do
            {:ok,
             %Price{
               date: date,
               commodity: currency,
               amount: amount,
               currency: quote_currency,
               metadata: metadata
             }, rest, next_line}
          end
        end

      _ ->
        {:error, error("invalid price directive", line_no, 1)}
    end
  end

  defp parse_note(date, rest_line, rest, line_no, opts) do
    case Lexer.split_tokens(rest_line) do
      [account | comment_tokens] ->
        {metadata_lines, rest, next_line} = collect_metadata_lines(rest, line_no)

        with {:ok, account} <- parse_account_token(account, opts),
             {:ok, comment} <- parse_quoted_token(Enum.join(comment_tokens, " "), opts),
             {:ok, metadata} <- parse_metadata(metadata_lines, opts) do
          {:ok, %Note{date: date, account: account, comment: comment, metadata: metadata}, rest,
           next_line}
        end

      _ ->
        {:error, error("invalid note directive", line_no, 1)}
    end
  end

  defp parse_document(date, rest_line, rest, line_no, opts) do
    case Lexer.split_tokens(rest_line) do
      [account | path_tokens] ->
        {metadata_lines, rest, next_line} = collect_metadata_lines(rest, line_no)

        with {:ok, account} <- parse_account_token(account, opts),
             {:ok, path} <- parse_quoted_token(Enum.join(path_tokens, " "), opts),
             {:ok, metadata} <- parse_metadata(metadata_lines, opts) do
          {:ok, %Document{date: date, account: account, path: path, metadata: metadata}, rest,
           next_line}
        end

      _ ->
        {:error, error("invalid document directive", line_no, 1)}
    end
  end

  defp parse_event(date, rest_line, rest, line_no, opts) do
    case Lexer.split_tokens(rest_line) do
      [type | description_tokens] ->
        {metadata_lines, rest, next_line} = collect_metadata_lines(rest, line_no)

        with {:ok, type} <- parse_quoted_token(type, opts),
             {:ok, description} <- parse_quoted_token(Enum.join(description_tokens, " "), opts),
             {:ok, metadata} <- parse_metadata(metadata_lines, opts) do
          {:ok, %Event{date: date, type: type, description: description, metadata: metadata},
           rest, next_line}
        end

      _ ->
        {:error, error("invalid event directive", line_no, 1)}
    end
  end

  defp parse_custom(date, rest_line, rest, line_no, opts) do
    case Lexer.split_tokens(rest_line) do
      [type | value_tokens] ->
        {metadata_lines, rest, next_line} = collect_metadata_lines(rest, line_no)

        with {:ok, type} <- parse_quoted_token(type, opts),
             {:ok, values} <- parse_custom_values(value_tokens, opts),
             {:ok, metadata} <- parse_metadata(metadata_lines, opts) do
          {:ok, %Custom{date: date, type: type, values: values, metadata: metadata}, rest,
           next_line}
        end

      _ ->
        {:error, error("invalid custom directive", line_no, 1)}
    end
  end

  defp parse_pad(date, rest_line, rest, line_no, opts) do
    case Lexer.split_tokens(rest_line) do
      [account, source_account | _] ->
        {metadata_lines, rest, next_line} = collect_metadata_lines(rest, line_no)

        with {:ok, account} <- parse_account_token(account, opts),
             {:ok, source_account} <- parse_account_token(source_account, opts),
             {:ok, metadata} <- parse_metadata(metadata_lines, opts) do
          {:ok,
           %Pad{date: date, account: account, source_account: source_account, metadata: metadata},
           rest, next_line}
        end

      _ ->
        {:error, error("invalid pad directive", line_no, 1)}
    end
  end

  defp parse_query(date, rest_line, rest, line_no, opts) do
    case Lexer.split_tokens(rest_line) do
      [name | bql_tokens] ->
        {metadata_lines, rest, next_line} = collect_metadata_lines(rest, line_no)

        with {:ok, name} <- parse_quoted_token(name, opts),
             {:ok, bql} <- parse_quoted_token(Enum.join(bql_tokens, " "), opts),
             {:ok, metadata} <- parse_metadata(metadata_lines, opts) do
          {:ok, %Query{date: date, name: name, bql: bql, metadata: metadata}, rest, next_line}
        end

      _ ->
        {:error, error("invalid query directive", line_no, 1)}
    end
  end

  defp parse_transaction(date, flag, rest_line, rest, line_no, opts) do
    {tags, links, header} = extract_tags_links(rest_line)
    {metadata_lines, posting_lines, rest, next_line} = collect_transaction_body(rest, line_no)

    with {:ok, payee, narration} <- parse_payee_narration(header, opts),
         {:ok, txn_metadata} <- parse_metadata(metadata_lines, opts),
         {:ok, postings} <- parse_postings(posting_lines, opts) do
      {:ok,
       %Transaction{
         date: date,
         flag: flag,
         payee: payee,
         narration: narration,
         postings: postings,
         tags: tags,
         links: links,
         metadata: txn_metadata
       }, rest, next_line}
    end
  end

  defp collect_transaction_body(rest, line_no, metadata \\ [], postings \\ []) do
    case rest do
      [line | tail] ->
        cond do
          line == "" or String.starts_with?(line, ";") ->
            {Enum.reverse(metadata), Enum.reverse(postings), tail, line_no + 1}

          posting_line?(line) ->
            collect_transaction_body(tail, line_no + 1, metadata, [line | postings])

          metadata_line?(line) ->
            collect_transaction_body(tail, line_no + 1, [line | metadata], postings)

          true ->
            {Enum.reverse(metadata), Enum.reverse(postings), rest, line_no}
        end

      [] ->
        {Enum.reverse(metadata), Enum.reverse(postings), [], line_no}
    end
  end

  defp collect_metadata_lines(rest, line_no, metadata \\ []) do
    case rest do
      [line | tail] ->
        cond do
          line == "" or String.starts_with?(line, ";") ->
            {Enum.reverse(metadata), tail, line_no + 1}

          metadata_line?(line) ->
            collect_metadata_lines(tail, line_no + 1, [line | metadata])

          true ->
            {Enum.reverse(metadata), rest, line_no}
        end

      [] ->
        {Enum.reverse(metadata), [], line_no}
    end
  end

  defp parse_payee_narration("", _opts), do: {:ok, nil, ""}

  defp parse_payee_narration(header, opts) do
    tokens = Lexer.split_tokens(header)

    case tokens do
      [payee, narration] ->
        with {:ok, payee} <- parse_quoted_token(payee, opts),
             {:ok, narration} <- parse_quoted_token(narration, opts) do
          {:ok, payee, narration}
        end

      [narration] ->
        with {:ok, narration} <- parse_quoted_token(narration, opts) do
          {:ok, nil, narration}
        end

      _ ->
        {:error, error("invalid transaction header", opts[:line], 1)}
    end
  end

  defp parse_postings(lines, opts) do
    Enum.reduce_while(lines, {:ok, []}, fn line, {:ok, acc} ->
      line_opts = Keyword.put(opts, :line, opts[:line])

      case Posting.parse_line(line, line_opts) do
        {:ok, posting} -> {:cont, {:ok, [posting | acc]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, postings} -> {:ok, Enum.reverse(postings)}
      other -> other
    end
  end

  defp parse_metadata(lines, opts) do
    lines
    |> Enum.filter(&metadata_line?/1)
    |> parse_metadata_map(opts)
  end

  defp parse_metadata_map(lines, opts) do
    Enum.reduce_while(lines, {:ok, %{}}, fn line, {:ok, acc} ->
      case Metadata.parse_line(line, opts) do
        {:ok, {key, value}} -> {:cont, {:ok, Map.put(acc, key, value)}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp metadata_line?(line) do
    String.starts_with?(line, "  ") and not posting_line?(line) and
      Regex.match?(~r/^\s+\S+\s*:/, line)
  end

  defp posting_line?(line) do
    String.starts_with?(line, "  ") and Regex.match?(~r/^\s+[!?]?[A-Z]/, line)
  end

  defp parse_option(text, opts) do
    tokens = Lexer.split_tokens(String.trim(text))

    case tokens do
      [name | value_tokens] ->
        with {:ok, name} <- parse_quoted_token(name, opts),
             {:ok, value} <- Metadata.parse_value(Enum.join(value_tokens, " "), opts) do
          {:ok, name, value}
        end

      _ ->
        {:error, error("invalid option directive", opts[:line], 1)}
    end
  end

  defp parse_plugin(text, opts) do
    tokens = Lexer.split_tokens(String.trim(text))

    case tokens do
      [module] ->
        with {:ok, module} <- parse_quoted_token(module, opts) do
          {:ok, %Plugin{module: module, config: nil}}
        end

      [module, config | _] ->
        with {:ok, module} <- parse_quoted_token(module, opts),
             {:ok, config} <- parse_quoted_token(config, opts) do
          {:ok, %Plugin{module: module, config: config}}
        end

      _ ->
        {:error, error("invalid plugin directive", opts[:line], 1)}
    end
  end

  defp parse_tag(text, opts) do
    text = String.trim(text)

    if String.starts_with?(text, "#") do
      {:ok, String.slice(text, 1..-1//1)}
    else
      {:error, error("expected tag", opts[:line], 1)}
    end
  end

  defp parse_custom_values(tokens, opts) do
    values =
      Enum.reduce_while(tokens, {:ok, []}, fn token, {:ok, acc} ->
        case parse_custom_value(token, opts) do
          {:ok, value} -> {:cont, {:ok, [value | acc]}}
          {:error, _} = err -> {:halt, err}
        end
      end)

    case values do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      other -> other
    end
  end

  defp parse_custom_value(token, opts) do
    cond do
      String.starts_with?(token, "\"") ->
        parse_quoted_token(token, opts)

      String.starts_with?(token, "#") ->
        {:ok, %Value.Tag{name: String.slice(token, 1..-1//1)}}

      Regex.match?(~r/^\d{4}-\d{2}-\d{2}$/, token) ->
        Date.from_iso8601(token)

      token in ["TRUE", "FALSE"] ->
        Metadata.parse_value(token, opts)

      true ->
        case Lexer.split_tokens(token) do
          [amount, currency | _] ->
            with {:ok, amount} <- parse_number_token(amount, opts),
                 {:ok, currency} <- parse_commodity_token(currency, opts) do
              {:ok, %Value.Amount{number: amount, currency: currency}}
            end

          _ ->
            case Lexer.parse_account(token) do
              {:ok, _, ""} -> {:ok, token}
              _ -> parse_number_token(token, opts)
            end
        end
    end
  end

  defp extract_tags_links(line) do
    tags =
      Regex.scan(~r/#([A-Za-z0-9_\-]+)/, line)
      |> Enum.map(fn [_, tag] -> tag end)

    links =
      Regex.scan(~r/\^([A-Za-z0-9_\-]+)/, line)
      |> Enum.map(fn [_, link] -> link end)

    cleaned =
      line
      |> String.replace(~r/#[A-Za-z0-9_\-]+/, "")
      |> String.replace(~r/\^[A-Za-z0-9_\-]+/, "")
      |> String.trim()

    {tags, links, cleaned}
  end

  defp parse_quoted_rest(text, opts), do: parse_quoted_token(String.trim(text), opts)

  defp parse_quoted_token(token, opts) do
    if is_quoted?(token) do
      case Lexer.parse_quoted_string(token) do
        {:ok, value, ""} -> {:ok, value}
        _ -> {:error, error("invalid quoted string", opts[:line], 1)}
      end
    else
      {:error, error("expected quoted string", opts[:line], 1)}
    end
  end

  defp parse_account_token(token, opts) do
    case Lexer.parse_account(token) do
      {:ok, _, ""} -> {:ok, token}
      _ -> {:error, error("invalid account", opts[:line], 1)}
    end
  end

  defp parse_commodity_token(token, opts) do
    case Lexer.parse_commodity(token) do
      {:ok, _, ""} -> {:ok, token}
      _ -> {:error, error("invalid commodity", opts[:line], 1)}
    end
  end

  defp parse_number_token(token, opts) do
    case Lexer.parse_number(token) do
      {:ok, value, ""} -> {:ok, value}
      _ -> {:error, error("invalid number", opts[:line], 1)}
    end
  end

  defp is_quoted?(token), do: String.starts_with?(token, "\"") and String.ends_with?(token, "\"")

  defp error(message, line, column) do
    %Error{message: message, line: line, column: column}
  end
end
