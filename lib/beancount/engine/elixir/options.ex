defmodule Beancount.Engine.Elixir.Options do
  @moduledoc false

  alias Beancount.Directives.Option

  # Option names Beancount recognizes. Unknown names are rejected (parity with
  # bean-check), even though only a subset changes native-engine behavior.
  @known_options MapSet.new(~w(
    title name_assets name_liabilities name_equity name_income name_expenses
    account_previous_balances account_previous_earnings account_previous_conversions
    account_current_earnings account_current_conversions account_unrealized_gains
    account_rounding conversion_currency inferred_tolerance_default
    inferred_tolerance_multiplier infer_tolerance_from_cost tolerance
    default_tolerance tolerance_multiplier use_legacy_fixed_tolerances documents
    operating_currency render_commas plugin_processing_mode plugin
    long_string_maxlines booking_method insert_pythonpath
    allow_deprecated_none_for_tags_and_links allow_pipe_separator
  ))

  @enforce_keys []
  # `operating_currency` is captured for round-trip/introspection but is not yet
  # consumed by any native report or check (reserved for future reporting).
  defstruct operating_currency: nil,
            inferred_tolerance_default: nil,
            inferred_tolerance_multiplier: Decimal.new(1),
            infer_tolerance_from_cost: false,
            tolerance_multiplier: Decimal.new(1)

  @type t :: %__MODULE__{
          operating_currency: String.t() | nil,
          inferred_tolerance_default: Decimal.t() | nil,
          inferred_tolerance_multiplier: Decimal.t(),
          infer_tolerance_from_cost: boolean(),
          tolerance_multiplier: Decimal.t()
        }

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec apply(t(), Option.t()) :: {t(), [map()]}
  def apply(options, %Option{name: name, value: value}) do
    case validate_and_put(options, name, value) do
      {:ok, options} -> {options, []}
      {:error, message} -> {options, [%{line: nil, message: message}]}
    end
  end

  defp validate_and_put(options, "operating_currency", value) when is_binary(value) do
    {:ok, %{options | operating_currency: value}}
  end

  defp validate_and_put(options, "inferred_tolerance_default", value) when is_binary(value) do
    case parse_tolerance_value(value) do
      {:ok, decimal} ->
        {:ok, %{options | inferred_tolerance_default: decimal}}

      :error ->
        {:error, "Error for option 'inferred_tolerance_default': Invalid value '#{value}'"}
    end
  end

  defp validate_and_put(_options, "inferred_tolerance_default", value) do
    {:error,
     "Error for option 'inferred_tolerance_default': Invalid value '#{inspect_value(value)}'"}
  end

  defp validate_and_put(options, "inferred_tolerance_multiplier", value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, ""} -> {:ok, %{options | inferred_tolerance_multiplier: decimal}}
      _ -> {:error, "Error for option 'inferred_tolerance_multiplier': Invalid value '#{value}'"}
    end
  end

  defp validate_and_put(options, "inferred_tolerance_multiplier", %Decimal{} = value) do
    {:ok, %{options | inferred_tolerance_multiplier: value}}
  end

  defp validate_and_put(options, "infer_tolerance_from_cost", value) when is_binary(value) do
    case String.upcase(value) do
      "TRUE" -> {:ok, %{options | infer_tolerance_from_cost: true}}
      "FALSE" -> {:ok, %{options | infer_tolerance_from_cost: false}}
      _ -> {:error, "syntax error, unexpected BOOL, expecting STRING"}
    end
  end

  defp validate_and_put(_options, "infer_tolerance_from_cost", _value) do
    {:error, "syntax error, unexpected BOOL, expecting STRING"}
  end

  defp validate_and_put(options, "tolerance_multiplier", value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, ""} -> {:ok, %{options | tolerance_multiplier: decimal}}
      _ -> {:error, "Error for option 'tolerance_multiplier': Invalid value '#{value}'"}
    end
  end

  defp validate_and_put(options, "tolerance_multiplier", %Decimal{} = value) do
    {:ok, %{options | tolerance_multiplier: value}}
  end

  defp validate_and_put(options, "title", _value), do: {:ok, options}

  defp validate_and_put(options, name, _value) do
    if MapSet.member?(@known_options, name) do
      {:ok, options}
    else
      {:error, "Invalid option: '#{name}'"}
    end
  end

  defp parse_tolerance_value(value) do
    case String.split(value, " ", parts: 2) do
      [number, _currency] ->
        case Decimal.parse(number) do
          {decimal, ""} -> {:ok, decimal}
          _ -> :error
        end

      [number] ->
        case Decimal.parse(number) do
          {decimal, ""} -> {:ok, decimal}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp inspect_value(true), do: "TRUE"
  defp inspect_value(false), do: "FALSE"
  defp inspect_value(value), do: to_string(value)
end
