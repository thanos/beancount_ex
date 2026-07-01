defmodule Beancount.Parser.Error do
  @moduledoc """
  Structured parse error for Beancount input.

  Every parse failure returns `%Beancount.Parser.Error{}` rather than raising
  a bare `FunctionClauseError`.
  """

  defexception [:message, :line, :column, :token]

  @type t :: %__MODULE__{
          message: String.t(),
          line: pos_integer() | nil,
          column: pos_integer() | nil,
          token: term() | nil
        }

  @doc """
  Build a parse error exception from keyword options.

  ## Examples

      error = Beancount.Parser.Error.exception(message: "syntax error", line: 3, column: 5)
      error.message
      # => "syntax error at line 3, column 5"

  """
  @impl true
  def exception(opts) do
    message = Keyword.get(opts, :message, "parse error")
    line = Keyword.get(opts, :line)
    column = Keyword.get(opts, :column)
    token = Keyword.get(opts, :token)

    detail =
      case {line, column} do
        {line, column} when is_integer(line) and is_integer(column) ->
          " at line #{line}, column #{column}"

        {line, _} when is_integer(line) ->
          " at line #{line}"

        _ ->
          ""
      end

    %__MODULE__{
      message: message <> detail,
      line: line,
      column: column,
      token: token
    }
  end
end
