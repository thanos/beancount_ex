defmodule Beancount.Parser do
  @moduledoc """
  Parse Beancount `.bean` text into typed directive structs.

  The parser covers the full Beancount grammar: transactions with cost and
  price annotations, balance assertions with tolerance, metadata, comments,
  tags, links, and all standard directives including `pad`, `include`,
  `option`, `query`, `plugin`, `pushtag`, and `poptag`.

  Parse failures return `{:error, %Beancount.Parser.Error{}}` with line and
  column information.
  """

  alias Beancount.Parser.{Error, Grammar}

  @doc """
  Parse a directive list or `.bean` text.

  Lists pass through unchanged; binaries are parsed.
  """
  @spec parse([Beancount.directive()] | binary()) ::
          {:ok, [Beancount.directive()]} | {:error, Error.t()}
  def parse(directives) when is_list(directives), do: {:ok, directives}

  def parse(text) when is_binary(text), do: parse_text(text)

  @doc """
  Parse `.bean` text into a directive list.
  """
  @spec parse_text(binary()) :: {:ok, [Beancount.directive()]} | {:error, Error.t()}
  def parse_text(text) when is_binary(text), do: Grammar.parse(text)

  @doc """
  Read and parse a `.bean` file from disk.
  """
  @spec parse_file(Path.t()) :: {:ok, [Beancount.directive()]} | {:error, term()}
  def parse_file(path) do
    case File.read(path) do
      {:ok, text} -> parse_text(text)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Parse `.bean` text, raising `Beancount.Parser.Error` on failure.
  """
  @spec parse!(binary()) :: [Beancount.directive()]
  def parse!(text) when is_binary(text) do
    case parse_text(text) do
      {:ok, directives} -> directives
      {:error, %Error{} = error} -> raise error
    end
  end
end
