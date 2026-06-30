defmodule Beancount.GoldenTest do
  use ExUnit.Case, async: true

  alias Beancount.Golden

  test "there is at least one golden fixture" do
    assert Golden.cases() != []
  end

  describe "ad-hoc case directory helpers" do
    setup do
      dir = Path.join(System.tmp_dir!(), "golden_helpers_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)
      %{dir: dir}
    end

    test "expected_bean/1 and expected_result/1 return nil when files are absent", %{dir: dir} do
      assert Golden.expected_bean(dir) == nil
      assert Golden.expected_result(dir) == nil
    end

    test "expected_result/1 decodes JSON when present", %{dir: dir} do
      File.write!(Golden.result_path(dir), ~s({"status":"ok","errors":[]}))
      assert Golden.expected_result(dir) == %{"status" => "ok", "errors" => []}
    end

    test "load_directives/1 and render/1 evaluate input.exs", %{dir: dir} do
      File.write!(Golden.input_path(dir), "[Beancount.commodity(~D[2026-01-01], \"USD\")]")

      assert [%Beancount.Directives.Commodity{currency: "USD"}] = Golden.load_directives(dir)
      assert Golden.render(dir) == "2026-01-01 commodity USD\n"
    end
  end

  for case_dir <- Beancount.Golden.cases() do
    @case_dir case_dir
    @name Path.basename(case_dir)

    test "golden render matches expected.bean for #{@name}" do
      expected = Golden.expected_bean(@case_dir)
      assert expected != nil, "missing expected.bean; run mix beancount.golden.update"
      assert Golden.render(@case_dir) == expected
    end

    test "rendering is deterministic for #{@name}" do
      assert Golden.render(@case_dir) == Golden.render(@case_dir)
    end
  end
end
