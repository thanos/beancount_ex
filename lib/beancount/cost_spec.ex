defmodule Beancount.CostSpec do
  @moduledoc """
  Beancount cost/lot specification for inventory postings.

  Supports the full cost grammar used in Beancount postings:

      {10 USD}                 per-unit cost
      {{100 USD}}              total cost
      {10 # 9.95 USD}          per-unit and total (e.g. commission)
      {10 USD, 2020-01-02}     with acquisition date
      {10 USD, "lot-a"}        with label
      {10 USD, merge}          merge lots
      {2020-01-01}             date only (lot override)
      {"magic lot"}            label only (lot selection)

  A legacy map `%{amount: decimal, currency: "USD"}` is accepted by
  `Beancount.posting/4` and normalized to this struct.
  """

  alias Beancount.Renderer

  @enforce_keys []
  defstruct [
    :per_amount,
    :per_currency,
    :total_amount,
    :total_currency,
    :date,
    :label,
    :merge
  ]

  @type t :: %__MODULE__{
          per_amount: Decimal.t() | nil,
          per_currency: String.t() | nil,
          total_amount: Decimal.t() | nil,
          total_currency: String.t() | nil,
          date: Date.t() | nil,
          label: String.t() | nil,
          merge: boolean()
        }

  @doc """
  Normalize a cost spec from a struct, legacy map, or `nil`.
  """
  @spec normalize(t() | map() | nil) :: t() | nil
  def normalize(nil), do: nil

  def normalize(%__MODULE__{} = spec), do: spec

  def normalize(%{amount: %Decimal{} = amount, currency: currency}) when is_binary(currency) do
    %__MODULE__{per_amount: amount, per_currency: currency, merge: false}
  end

  @doc """
  Render a cost spec as a Beancount `{...}` or `{{...}}` suffix (without leading space).
  """
  @spec to_string(t()) :: binary()
  def to_string(%__MODULE__{} = spec) do
    cond do
      total_only?(spec) ->
        "{{" <>
          amount_currency(spec.total_amount, spec.total_currency) <> suffix_extras(spec) <> "}}"

      per_and_total?(spec) ->
        "{" <>
          Renderer.format_decimal(spec.per_amount) <>
          " # " <>
          Renderer.format_decimal(spec.total_amount) <>
          " " <>
          cost_currency(spec) <> suffix_extras(spec) <> "}"

      date_only?(spec) ->
        "{" <> Renderer.format_date(spec.date) <> extras_merge_only(spec) <> "}"

      label_only?(spec) ->
        "{" <> Renderer.quote_string(spec.label) <> extras_merge_only(spec) <> "}"

      has_per?(spec) ->
        "{" <>
          amount_currency(spec.per_amount, spec.per_currency) <>
          suffix_extras(spec) <> "}"

      true ->
        raise ArgumentError, "invalid cost spec: #{inspect(spec)}"
    end
  end

  defp total_only?(%__MODULE__{per_amount: nil, total_amount: %Decimal{}}), do: true
  defp total_only?(_), do: false

  defp per_and_total?(%__MODULE__{per_amount: %Decimal{}, total_amount: %Decimal{}}), do: true
  defp per_and_total?(_), do: false

  defp date_only?(%__MODULE__{per_amount: nil, total_amount: nil, date: %Date{}, label: nil}),
    do: true

  defp date_only?(_), do: false

  defp label_only?(%__MODULE__{per_amount: nil, total_amount: nil, label: label})
       when is_binary(label),
       do: true

  defp label_only?(_), do: false

  defp has_per?(%__MODULE__{per_amount: %Decimal{}, per_currency: currency})
       when is_binary(currency),
       do: true

  defp has_per?(_), do: false

  defp amount_currency(%Decimal{} = amount, currency),
    do: Renderer.format_decimal(amount) <> " " <> currency

  defp cost_currency(%__MODULE__{per_currency: currency}) when is_binary(currency), do: currency

  defp cost_currency(%__MODULE__{total_currency: currency}) when is_binary(currency),
    do: currency

  defp suffix_extras(spec) do
    []
    |> maybe_add_date(spec.date)
    |> maybe_add_label(spec.label)
    |> maybe_add_merge(spec.merge)
    |> join_extras()
  end

  defp extras_merge_only(spec) do
    []
    |> maybe_add_merge(spec.merge)
    |> join_extras()
  end

  defp join_extras([]), do: ""
  defp join_extras(parts), do: ", " <> Enum.join(parts, ", ")

  defp maybe_add_date(parts, %Date{} = date), do: parts ++ [Renderer.format_date(date)]
  defp maybe_add_date(parts, _), do: parts

  defp maybe_add_label(parts, label) when is_binary(label),
    do: parts ++ [Renderer.quote_string(label)]

  defp maybe_add_label(parts, _), do: parts

  defp maybe_add_merge(parts, true), do: parts ++ ["merge"]
  defp maybe_add_merge(parts, _), do: parts
end
