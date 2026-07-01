defmodule Beancount.Engine.Elixir.Tolerance do
  @moduledoc false

  alias Beancount.Engine.Elixir.Options

  @spec infer(Options.t(), String.t(), [Decimal.t()]) :: Decimal.t()
  def infer(%Options{} = options, _currency, amounts) do
    amounts
    |> Enum.map(&precision_tolerance/1)
    |> Enum.concat([options.inferred_tolerance_default])
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> Decimal.new(0)
      amounts -> Enum.reduce(amounts, &Decimal.max/2)
    end
    |> Decimal.mult(options.inferred_tolerance_multiplier)
    |> Decimal.mult(options.tolerance_multiplier)
  end

  @spec within?(Decimal.t(), Decimal.t(), Decimal.t()) :: boolean()
  def within?(actual, expected, tolerance) do
    Decimal.sub(actual, expected) |> Decimal.abs() |> Decimal.lte?(tolerance)
  end

  defp precision_tolerance(%Decimal{} = amount) do
    amount
    |> Decimal.normalize()
    |> Decimal.to_string(:normal)
    |> decimal_places()
    |> then(fn places ->
      if places == 0 do
        Decimal.new("0.5")
      else
        scale = :math.pow(10, -places) |> Decimal.from_float()
        Decimal.mult(Decimal.new("0.5"), scale)
      end
    end)
  end

  defp decimal_places(string) do
    case String.split(string, ".") do
      [_int] -> 0
      [_, frac] -> String.length(frac)
    end
  end
end
