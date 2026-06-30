defmodule Beancount.Normalizer do
  @moduledoc """
  Normalizes raw engine output into a stable, engine-independent structure.

  Normalization is what makes Beancount usable as an *oracle*: two different
  engines (the CLI today, a native engine tomorrow) can be compared on their
  normalized output rather than on incidental, backend-specific text such as
  temporary file paths.

  The normalized map has the shape:

      %{
        status: :ok | :error,
        errors: [%{line: non_neg_integer() | nil, message: String.t()}]
      }

  """

  @error_regex ~r/^(?<file>.*?):(?<line>\d+):\s*(?<message>.*)$/

  @type error :: %{line: non_neg_integer() | nil, message: String.t()}
  @type t :: %{status: Beancount.Result.status(), errors: [error()]}

  @doc """
  Normalize captured `stdout`/`stderr` for a given exit status.

  `source_path`, when provided, is stripped from error lines so that the
  normalized output does not depend on temporary file locations and stays
  deterministic.

  ## Examples

      iex> Beancount.Normalizer.normalize(0, "", "")
      %{status: :ok, errors: []}

      iex> Beancount.Normalizer.normalize(1, "", "/tmp/x.bean:3: Invalid")
      %{status: :error, errors: [%{line: 3, message: "Invalid"}]}

  """
  @spec normalize(non_neg_integer() | nil, binary(), binary(), binary() | nil) :: t()
  def normalize(exit_status, stdout, stderr, source_path \\ nil) do
    status = if exit_status in [0, nil], do: :ok, else: :error

    errors =
      [stdout, stderr]
      |> Enum.flat_map(&parse_lines(&1, source_path))
      |> Enum.sort_by(&{&1.message, &1.line || 0})

    %{status: status, errors: errors}
  end

  defp parse_lines(output, source_path) do
    output
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&parse_line(&1, source_path))
  end

  defp parse_line(line, source_path) do
    case Regex.named_captures(@error_regex, line) do
      %{"line" => line_no, "message" => message} ->
        %{line: String.to_integer(line_no), message: normalize_message(message, source_path)}

      nil ->
        %{line: nil, message: normalize_message(line, source_path)}
    end
  end

  defp normalize_message(message, nil), do: message

  defp normalize_message(message, source_path) do
    String.replace(message, source_path, "<input>")
  end
end
