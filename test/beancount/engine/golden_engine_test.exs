defmodule Beancount.Engine.Elixir.GoldenEngineTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Beancount.Engine.Elixir, as: NativeEngine
  alias Beancount.Golden

  for case_dir <- Golden.cases() do
    @case_dir case_dir
    @name Path.basename(case_dir)

    test "native check status matches golden result for #{@name}" do
      expected = Golden.expected_result(@case_dir)
      assert expected != nil, "missing expected.result.json for #{@name}"

      bean = Golden.expected_bean(@case_dir)
      assert bean != nil, "missing expected.bean for #{@name}"

      case NativeEngine.check(bean) do
        {:ok, %Beancount.Result{status: :ok}} ->
          assert expected["status"] == "ok"

        {:error, %Beancount.Result{status: :error}} ->
          assert expected["status"] == "error"
      end
    end
  end
end
