defmodule Beancount.Engine.Elixir do
  @moduledoc """
  Native Elixir engine: parse, render, booking-aware check, and canned reports.

  v0.4 provides full parity with the CLI oracle on the 29 golden fixtures via
  `Beancount.Compare.compare/3` (booking, balance assertions, pad resolution,
  tolerance inference, and canned reports).
  """

  @behaviour Beancount.Engine

  alias Beancount.Engine.Elixir.{Reports, Validator}
  alias Beancount.{Parser, Renderer, Result}

  @impl Beancount.Engine
  def render(directives) when is_list(directives), do: Renderer.render(directives)

  @impl Beancount.Engine
  def check(text) when is_binary(text) do
    case Parser.parse_text(text) do
      {:ok, directives} -> Validator.validate(directives)
      {:error, %Parser.Error{} = error} -> validation_error([error])
    end
  end

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
