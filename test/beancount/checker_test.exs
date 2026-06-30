defmodule Beancount.CheckerTest do
  use ExUnit.Case, async: false

  alias Beancount.Checker

  setup do
    original = Application.get_env(:beancount_ex, :bean_check_path)
    on_exit(fn -> Application.put_env(:beancount_ex, :bean_check_path, original) end)
    :ok
  end

  test "bean_check_path/0 reflects configuration" do
    Application.put_env(:beancount_ex, :bean_check_path, "/some/where/bean-check")
    assert Checker.bean_check_path() == "/some/where/bean-check"
  end

  test "available?/0 is false for a missing executable" do
    Application.put_env(:beancount_ex, :bean_check_path, "definitely-not-a-real-binary-xyz")
    refute Checker.available?()
  end

  test "check_text/1 raises NotInstalledError when bean-check is unavailable" do
    Application.put_env(:beancount_ex, :bean_check_path, "definitely-not-a-real-binary-xyz")

    assert_raise Checker.NotInstalledError, fn ->
      Checker.check_text("2026-01-01 open Assets:Bank USD\n")
    end
  end

  test "check_file/1 raises NotInstalledError when bean-check is unavailable" do
    Application.put_env(:beancount_ex, :bean_check_path, "definitely-not-a-real-binary-xyz")

    assert_raise Checker.NotInstalledError, fn ->
      Checker.check_file("whatever.bean")
    end
  end

  describe "with a fake bean-check executable" do
    setup do
      Beancount.FakeBeanCheck.install!()
      :ok
    end

    test "available?/0 is true for a regular executable file" do
      assert Checker.available?()
    end

    test "check_text/1 returns {:ok, result} for valid input" do
      assert {:ok, result} = Checker.check_text("2026-01-01 open Assets:Bank USD\n")
      assert %Beancount.Result{status: :ok, exit_status: 0} = result
      assert result.normalized == %{status: :ok, errors: []}
    end

    test "check_text/1 returns {:error, result} for failing input" do
      assert {:error, result} = Checker.check_text("FAIL this ledger\n")
      assert %Beancount.Result{status: :error, exit_status: 1} = result
      assert [%{message: message}] = result.normalized.errors
      assert message =~ "forced failure"
      refute message =~ System.tmp_dir!()
    end

    test "check_file/1 validates a file on disk" do
      path = Path.join(System.tmp_dir!(), "checker_#{System.unique_integer([:positive])}.bean")
      File.write!(path, "2026-01-01 open Assets:Bank USD\n")
      on_exit(fn -> File.rm(path) end)

      assert {:ok, %Beancount.Result{status: :ok}} = Checker.check_file(path)
    end

    test "Beancount.check/1 dispatches through the engine to the fake" do
      ledger = [Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"])]
      assert {:ok, %Beancount.Result{status: :ok}} = Beancount.check(ledger)
    end
  end
end
