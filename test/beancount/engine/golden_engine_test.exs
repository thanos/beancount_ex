defmodule Beancount.Engine.Elixir.GoldenEngineTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Beancount.Engine.Elixir, as: NativeEngine
  alias Beancount.Golden

  for case_dir <- Golden.cases() do
    @case_dir case_dir
    @name Path.basename(case_dir)

    test "native check processes golden fixture #{@name}" do
      bean = Golden.expected_bean(@case_dir)
      assert bean != nil, "missing expected.bean for #{@name}"

      case NativeEngine.check(bean) do
        {:ok, %Beancount.Result{status: :ok}} -> :ok
        {:error, %Beancount.Result{status: :error}} -> :ok
      end
    end
  end
end
