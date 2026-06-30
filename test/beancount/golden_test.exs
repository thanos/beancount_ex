defmodule Beancount.GoldenTest do
  use ExUnit.Case, async: true

  alias Beancount.Golden

  @compare_equivalent ~w(
    basic_txn
    directives
    salary
  )

  @compare_deferred ~w(
    account_not_opened
    balance_assertion
    balance_interpolation
    balance_missing_amount_currency
    balance_single
    booking_add_override
    booking_infer_price
    booking_lifo
    booking_lifo_short
    booking_move_inventory
    booking_sell_fifo
    booking_short_cross_line
    booking_spec_ambiguous
    booking_spec_inferred_not_ambiguous
    booking_spec_too_small
    booking_stock_split
    booking_strict
    booking_strict_cancel_all
    booking_strict_miss
    booking_strict_no_cost_spec
    double_open
    include_not_found
    options
    pad
    pad_not_plain
    tolerance
  )

  test "there is at least one golden fixture" do
    assert Golden.cases() != []
  end

  test "cases/0 returns an empty list when the golden root is missing" do
    original = File.cwd!()
    empty = Path.join(System.tmp_dir!(), "golden_missing_#{System.unique_integer([:positive])}")
    File.mkdir_p!(empty)

    on_exit(fn ->
      File.cd!(original)
      File.rm_rf!(empty)
    end)

    File.cd!(empty)
    assert Golden.cases() == []
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

    test "parse round-trips expected.bean for #{@name}" do
      expected = Golden.expected_bean(@case_dir)
      assert expected != nil, "missing expected.bean; run mix beancount.golden.update"

      assert {:ok, directives} = Beancount.parse_text(expected)
      assert Beancount.render(directives) == expected
    end

    @tag :beancount
    test "compare/3 oracle equivalence for #{@name}" do
      expected = Golden.expected_bean(@case_dir)
      assert expected != nil, "missing expected.bean; run mix beancount.golden.update"

      result =
        Beancount.Compare.compare(
          Beancount.Engine.CLI,
          Beancount.Engine.Elixir,
          expected
        )

      cond do
        @name in @compare_equivalent ->
          assert {:ok, :equivalent} = result

        @name in @compare_deferred ->
          assert match?({:ok, :deferred}, result) or
                   match?({:error, %Beancount.Property.Diff{}}, result)

        true ->
          flunk("golden fixture #{@name} is not categorized for compare/3")
      end
    end
  end
end
