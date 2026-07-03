defmodule Beancount.Engine.Elixir do
  @moduledoc """
  Native Elixir engine: parse, render, booking-aware check, and canned reports.

  Full parity with the CLI oracle is asserted on the golden fixtures via
  `Beancount.Compare.compare/3`.
  """

  @behaviour Beancount.Engine

  alias Beancount.Engine.Elixir.{Reports, Validator}
  alias Beancount.{Parser, Renderer, Result}

  @doc """
  Render directives to `.bean` text via `Beancount.Renderer`.

  ## Examples

      iex> Beancount.Engine.Elixir.render([Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"])])
      "2026-01-01 open Assets:Bank USD\\n"

  """
  @impl Beancount.Engine
  def render(directives) when is_list(directives), do: Renderer.render(directives)

  @doc """
  Parse and validate `.bean` text with the native booking engine.

  ## Examples

      iex> text = \"\"\"
      ...> 2026-01-01 open Assets:Bank USD
      ...> 2026-01-01 open Income:Salary USD
      ...> 2026-01-01 open Equity:Opening USD
      ...>
      ...> 2026-01-31 * "Employer" "Salary"
      ...>   Assets:Bank     100 USD
      ...>   Income:Salary  -100 USD
      ...> \"\"\"
      iex> {:ok, %Beancount.Result{status: :ok}} = Beancount.Engine.Elixir.check(text)

  """
  @impl Beancount.Engine
  def check(text) when is_binary(text) do
    case Parser.parse_text(text) do
      {:ok, directives} -> Validator.validate(directives)
      {:error, %Parser.Error{} = error} -> validation_error([error])
    end
  end

  @doc """
  Read and validate a `.bean` file from disk.

  ## Examples

      path = Path.join(System.tmp_dir!(), "elixir_check.bean")

      File.write!(path, \"\"\"
      2026-01-01 open Assets:Bank USD
      2026-01-01 open Income:Salary USD
      2026-01-01 open Equity:Opening USD

      2026-01-31 * "Employer" "Salary"
        Assets:Bank     100 USD
        Income:Salary  -100 USD
      \"\"\")

      {:ok, %Beancount.Result{status: :ok}} = Beancount.Engine.Elixir.check_file(path)

  """
  @impl Beancount.Engine
  def check_file(path) do
    case File.read(path) do
      {:ok, text} ->
        case Parser.parse_text(text) do
          {:ok, directives} -> Validator.validate(directives, include_base: path)
          {:error, %Parser.Error{} = error} -> validation_error([error])
        end

      {:error, reason} ->
        raise File.Error, reason: reason, action: "read file", path: path
    end
  end

  @doc """
  Parse the ledger and run a canned report query.

  ## Examples

      iex> text = \"\"\"
      ...> 2026-01-01 open Assets:Bank USD
      ...> 2026-01-01 open Income:Salary USD
      ...> 2026-01-01 open Equity:Opening USD
      ...>
      ...> 2026-01-31 * "Employer" "Salary"
      ...>   Assets:Bank     100 USD
      ...>   Income:Salary  -100 USD
      ...> \"\"\"
      iex> {:ok, %Beancount.Query.Result{columns: cols}} =
      ...>   Beancount.Engine.Elixir.query(text, "SELECT account, sum(position) AS balance GROUP BY account ORDER BY account")
      iex> cols
      ["account", "balance"]

  """
  @impl Beancount.Engine
  def query(text, bql) when is_binary(text) and is_binary(bql) do
    case Parser.parse_text(text) do
      {:ok, directives} -> Reports.run(directives, bql)
      {:error, %Parser.Error{} = error} -> validation_error([error])
    end
  end

  defp validation_error(errors) do
    normalized = %{
      status: :error,
      errors:
        Enum.map(errors, fn
          %Parser.Error{message: message, line: line} -> %{line: line, message: message}
          %{line: line, message: message} -> %{line: line, message: message}
        end)
    }

    {:error,
     %Result{
       status: :error,
       exit_status: 1,
       stdout: "",
       stderr: "",
       normalized: normalized
     }}
  end
end
