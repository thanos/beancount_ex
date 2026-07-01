defmodule Beancount.BQL.Parser do
  @moduledoc false

  alias Beancount.BQL.AST.{Column, Order, Query}

  @clause_pattern ~r/\b(WHERE|GROUP\s+BY|ORDER\s+BY|LIMIT)\b/i

  @spec parse(binary()) :: {:ok, Query.t()} | {:error, term()}
  def parse(bql) when is_binary(bql) do
    bql = normalize(bql)

    with {:ok, select, rest} <- parse_select(bql),
         {:ok, where, rest} <- parse_optional_where(rest),
         {:ok, group_by, rest} <- parse_optional_group_by(rest),
         {:ok, order_by, rest} <- parse_optional_order_by(rest),
         {:ok, limit, rest} <- parse_optional_limit(rest),
         :ok <- ensure_rest_empty(rest) do
      {:ok,
       %Query{
         select: select,
         where: where,
         group_by: group_by,
         order_by: order_by,
         limit: limit
       }}
    end
  end

  defp normalize(bql) do
    bql |> String.replace(~r/\s+/, " ") |> String.trim()
  end

  defp parse_select("SELECT " <> rest) do
    case next_clause_index(rest) do
      nil ->
        with {:ok, columns} <- parse_columns(rest) do
          {:ok, columns, ""}
        end

      index ->
        columns_text = rest |> String.slice(0, index) |> String.trim()
        clause_rest = rest |> String.slice(index..-1//1) |> String.trim()

        with {:ok, columns} <- parse_columns(columns_text) do
          {:ok, columns, clause_rest}
        end
    end
  end

  defp parse_select(_), do: {:error, {:bql, "expected SELECT"}}

  defp parse_optional_where(""), do: {:ok, nil, ""}

  defp parse_optional_where("WHERE " <> rest) do
    case next_clause_index(rest) do
      nil ->
        with {:ok, expr} <- parse_expr(rest), do: {:ok, expr, ""}

      index ->
        expr_text = rest |> String.slice(0, index) |> String.trim()
        clause_rest = rest |> String.slice(index..-1//1) |> String.trim()

        with {:ok, expr} <- parse_expr(expr_text) do
          {:ok, expr, clause_rest}
        end
    end
  end

  defp parse_optional_where(text), do: {:ok, nil, text}

  defp parse_optional_group_by(""), do: {:ok, [], ""}

  defp parse_optional_group_by("GROUP BY " <> rest) do
    case next_clause_index(rest) do
      nil ->
        with {:ok, columns} <- parse_expr_list(rest), do: {:ok, columns, ""}

      index ->
        cols_text = rest |> String.slice(0, index) |> String.trim()
        clause_rest = rest |> String.slice(index..-1//1) |> String.trim()

        with {:ok, columns} <- parse_expr_list(cols_text) do
          {:ok, columns, clause_rest}
        end
    end
  end

  defp parse_optional_group_by(text), do: {:ok, [], text}

  defp parse_optional_order_by(""), do: {:ok, [], ""}

  defp parse_optional_order_by("ORDER BY " <> rest) do
    case next_clause_index(rest) do
      nil ->
        with {:ok, orders} <- parse_order_list(rest), do: {:ok, orders, ""}

      index ->
        cols_text = rest |> String.slice(0, index) |> String.trim()
        clause_rest = rest |> String.slice(index..-1//1) |> String.trim()

        with {:ok, orders} <- parse_order_list(cols_text) do
          {:ok, orders, clause_rest}
        end
    end
  end

  defp parse_optional_order_by(text), do: {:ok, [], text}

  defp parse_optional_limit(""), do: {:ok, nil, ""}

  defp parse_optional_limit("LIMIT " <> rest) do
    case Integer.parse(String.trim(rest)) do
      {limit, ""} -> {:ok, limit, ""}
      {limit, " " <> _} -> {:ok, limit, ""}
      _ -> {:error, {:bql, "invalid LIMIT"}}
    end
  end

  defp parse_optional_limit(text), do: {:ok, nil, text}

  defp next_clause_index(text) do
    case Regex.run(@clause_pattern, text, return: :index) do
      [{index, _length} | _] -> index
      nil -> nil
    end
  end

  defp parse_columns(text) do
    text
    |> split_commas()
    |> Enum.reduce_while({:ok, []}, fn part, {:ok, acc} ->
      case parse_column(part) do
        {:ok, column} -> {:cont, {:ok, [column | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, columns} -> {:ok, Enum.reverse(columns)}
      error -> error
    end
  end

  defp parse_column(text) do
    case Regex.run(~r/^(.+?)\s+AS\s+([A-Za-z_][A-Za-z0-9_]*)$/i, text) do
      [_, expr_text, alias] ->
        with {:ok, expr} <- parse_expr(expr_text) do
          {:ok, %Column{expr: expr, as: alias}}
        end

      _ ->
        with {:ok, expr} <- parse_expr(text) do
          {:ok, %Column{expr: expr, as: default_alias(expr)}}
        end
    end
  end

  defp default_alias({:ident, name}), do: name
  defp default_alias({:func, name, _}), do: Atom.to_string(name)
  defp default_alias(_), do: nil

  defp parse_expr_list(text) do
    text
    |> split_commas()
    |> Enum.reduce_while({:ok, []}, fn part, {:ok, acc} ->
      case parse_expr(part) do
        {:ok, expr} -> {:cont, {:ok, [expr | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, exprs} -> {:ok, Enum.reverse(exprs)}
      error -> error
    end
  end

  defp parse_order_list(text) do
    text
    |> split_commas()
    |> Enum.reduce_while({:ok, []}, fn part, {:ok, acc} ->
      case parse_order(part) do
        {:ok, order} -> {:cont, {:ok, [order | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, orders} -> {:ok, Enum.reverse(orders)}
      error -> error
    end
  end

  defp parse_order(text) do
    cond do
      String.match?(text, ~r/\s+DESC$/i) ->
        expr_text = text |> String.replace(~r/\s+DESC$/i, "") |> String.trim()

        with {:ok, expr} <- parse_expr(expr_text) do
          {:ok, %Order{expr: expr, direction: :desc}}
        end

      String.match?(text, ~r/\s+ASC$/i) ->
        expr_text = text |> String.replace(~r/\s+ASC$/i, "") |> String.trim()

        with {:ok, expr} <- parse_expr(expr_text) do
          {:ok, %Order{expr: expr, direction: :asc}}
        end

      true ->
        with {:ok, expr} <- parse_expr(text) do
          {:ok, %Order{expr: expr, direction: :asc}}
        end
    end
  end

  defp parse_expr(text) do
    text = String.trim(text)

    cond do
      text == "" ->
        {:error, {:bql, "empty expression"}}

      String.match?(text, ~r/^NOT\s+/i) ->
        inner = text |> String.replace(~r/^NOT\s+/i, "") |> String.trim()
        with {:ok, expr} <- parse_expr(inner), do: {:ok, {:unary, :not, expr}}

      match = Regex.run(~r/^(.+?)\s+(~|=|!=|<=|>=|<|>)\s+(.+)$/s, text) ->
        [_, left_text, op, right_text] = match

        with {:ok, left} <- parse_value_expr(String.trim(left_text)),
             {:ok, right} <- parse_value_expr(String.trim(right_text)) do
          {:ok, {:binary, op_to_atom(op), left, right}}
        end

      true ->
        parse_value_expr(text)
    end
  end

  defp op_to_atom("~"), do: :regex
  defp op_to_atom("="), do: :eq
  defp op_to_atom("!="), do: :neq
  defp op_to_atom("<="), do: :lte
  defp op_to_atom(">="), do: :gte
  defp op_to_atom("<"), do: :lt
  defp op_to_atom(">"), do: :gt

  defp parse_value_expr(text) do
    cond do
      String.match?(text, ~r/^".*"$/) ->
        {:ok, {:string, unquote_string(text)}}

      String.match?(text, ~r/^[+-]?\d+(?:\.\d+)?$/) ->
        {:ok, {:number, Decimal.new(text)}}

      func_match = Regex.run(~r/^([A-Za-z_][A-Za-z0-9_]*)\((.*)\)$/s, text) ->
        [_, name, args_text] = func_match

        with {:ok, func} <- parse_func_name(name),
             {:ok, args} <- parse_func_args(args_text) do
          {:ok, {:func, func, args}}
        end

      ident?(text) ->
        {:ok, {:ident, text}}

      true ->
        {:error, {:bql, "invalid expression: #{text}"}}
    end
  end

  defp parse_func_name("sum"), do: {:ok, :sum}
  defp parse_func_name("units"), do: {:ok, :units}
  defp parse_func_name("cost"), do: {:ok, :cost}
  defp parse_func_name("count"), do: {:ok, :count}
  defp parse_func_name("date"), do: {:ok, :date}
  defp parse_func_name("flag"), do: {:ok, :flag}
  defp parse_func_name("payee"), do: {:ok, :payee}
  defp parse_func_name("narration"), do: {:ok, :narration}
  defp parse_func_name("position"), do: {:ok, :position}
  defp parse_func_name("balance"), do: {:ok, :balance}
  defp parse_func_name(other), do: {:error, {:bql, "unknown function #{other}"}}

  defp parse_func_args("*"), do: {:ok, [{:ident, "*"}]}

  defp parse_func_args(text) do
    parse_expr_list(text)
  end

  defp ident?(text) do
    Regex.match?(~r/^[A-Za-z_*][A-Za-z0-9_*]*$/, text)
  end

  defp unquote_string("\"" <> rest) do
    rest
    |> String.trim_trailing("\"")
    |> String.replace(~r/\\"/, "\"")
    |> String.replace(~r/\\\\/, "\\")
  end

  defp split_commas(text) do
    text
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp ensure_rest_empty(""), do: :ok
  defp ensure_rest_empty(rest), do: {:error, {:bql, "unexpected trailing input: #{rest}"}}
end
