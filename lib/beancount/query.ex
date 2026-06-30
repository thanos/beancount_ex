defmodule Beancount.Query do
  @moduledoc """
  Low-level wrapper around the `bean-query` command-line tool.

  `Query` is the only place that shells out to `bean-query`, mirroring how
  `Beancount.Checker` wraps `bean-check`. It runs a BQL query against a ledger
  with CSV output and parses the result into a neutral
  `Beancount.Query.Result`.

  The path to `bean-query` is configurable:

      config :beancount_ex, bean_query_path: "bean-query"

  """

  alias Beancount.{Normalizer, Result}
  alias Beancount.Query.Result, as: QueryResult

  defmodule NotInstalledError do
    @moduledoc """
    Raised when the configured `bean-query` executable cannot be located.

    This signals an environment/setup problem, distinct from a query that fails
    (which is returned as `{:error, %Beancount.Result{}}`).
    """
    defexception [:message]
  end

  @doc """
  Return the configured path to the `bean-query` executable.
  """
  @spec bean_query_path() :: String.t()
  def bean_query_path do
    Application.get_env(:beancount_ex, :bean_query_path, "bean-query")
  end

  @doc """
  Whether the configured `bean-query` executable is available on this machine.
  """
  @spec available?() :: boolean()
  def available? do
    path = bean_query_path()
    File.regular?(path) or System.find_executable(path) != nil
  end

  @doc """
  Run `bql` against ledger `text`, writing it to a temporary file first.
  """
  @spec query_text(binary(), binary()) :: {:ok, QueryResult.t()} | {:error, Result.t()}
  def query_text(text, bql) when is_binary(text) and is_binary(bql) do
    path =
      Path.join(System.tmp_dir!(), "beancount_ex_q_#{System.unique_integer([:positive])}.bean")

    File.write!(path, text)

    try do
      query_file(path, bql)
    after
      File.rm(path)
    end
  end

  @doc """
  Run `bql` against a `.bean` file on disk.

  Raises `Beancount.Query.NotInstalledError` if `bean-query` is not available.
  """
  @spec query_file(Path.t(), binary()) :: {:ok, QueryResult.t()} | {:error, Result.t()}
  def query_file(path, bql) when is_binary(bql) do
    ensure_available!()

    {output, exit_status} =
      System.cmd(bean_query_path(), ["-f", "csv", path, bql], stderr_to_stdout: true)

    build_result(exit_status, output, path)
  end

  defp build_result(0, output, _source_path) do
    {columns, rows} = parse_csv(output)
    {:ok, %QueryResult{columns: columns, rows: rows, raw: output, status: :ok}}
  end

  defp build_result(exit_status, output, source_path) do
    normalized = Normalizer.normalize(exit_status, output, "", source_path)

    {:error,
     %Result{
       status: :error,
       exit_status: exit_status,
       stdout: output,
       stderr: "",
       normalized: normalized
     }}
  end

  defp ensure_available! do
    unless available?() do
      raise NotInstalledError,
        message:
          "bean-query executable not found at #{inspect(bean_query_path())}. " <>
            "Install beanquery (`pip install beanquery`) or configure " <>
            ":beancount_ex, :bean_query_path."
    end
  end

  @doc """
  Parse RFC-4180-style CSV text into `{columns, rows}`.

  The first non-empty line is treated as the header. Empty input yields
  `{[], []}`. Quoted fields may contain embedded newlines.
  """
  @spec parse_csv(binary()) :: {[String.t()], [[String.t()]]}
  def parse_csv(csv) do
    trimmed = String.trim(csv)

    case parse_rows(trimmed, [], [], "", false) do
      [] -> {[], []}
      [header | rows] -> {header, rows}
    end
  end

  defp parse_rows("", rows, row, field, false) do
    rows = finalize_row(rows, row, field)
    Enum.reverse(rows)
  end

  defp parse_rows("", _rows, _row, _field, true) do
    raise ArgumentError, "unclosed double quote in CSV field"
  end

  defp parse_rows(<<?", ?", rest::binary>>, rows, row, field, true) do
    parse_rows(rest, rows, row, field <> "\"", true)
  end

  defp parse_rows(<<?", rest::binary>>, rows, row, field, in_quotes) do
    parse_rows(rest, rows, row, field, not in_quotes)
  end

  defp parse_rows(<<?,, rest::binary>>, rows, row, field, false) do
    parse_rows(rest, rows, row ++ [field], "", false)
  end

  defp parse_rows(<<?\r, ?\n, rest::binary>>, rows, row, field, false) do
    parse_rows(rest, finalize_row(rows, row, field), [], "", false)
  end

  defp parse_rows(<<?\n, rest::binary>>, rows, row, field, false) do
    parse_rows(rest, finalize_row(rows, row, field), [], "", false)
  end

  defp parse_rows(<<?\r, rest::binary>>, rows, row, field, false) do
    parse_rows(rest, finalize_row(rows, row, field), [], "", false)
  end

  defp parse_rows(<<char::utf8, rest::binary>>, rows, row, field, in_quotes) do
    parse_rows(rest, rows, row, field <> <<char::utf8>>, in_quotes)
  end

  defp finalize_row(rows, row, field) do
    if row == [] and field == "" do
      rows
    else
      [row ++ [field] | rows]
    end
  end
end
