defmodule Beancount.EngineTest do
  use ExUnit.Case, async: false

  alias Beancount.Engine

  setup do
    Beancount.FakeEngine.ensure!()
    :ok
  end

  test "configured/0 returns the CLI engine by default" do
    assert Engine.configured() == Beancount.Engine.CLI
  end

  test "CLI engine render/1 delegates to the Renderer" do
    directives = [Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"])]
    assert Engine.CLI.render(directives) == Beancount.Renderer.render(directives)
  end

  test "CLI engine check/1 delegates to Checker" do
    Beancount.FakeBeanCheck.install!()

    assert {:ok, %Beancount.Result{status: :ok}} =
             Engine.CLI.check("2026-01-01 open Assets:Bank USD\n")
  end

  test "CLI engine check_file/1 delegates to Checker" do
    Beancount.FakeBeanCheck.install!()

    path =
      Path.join(System.tmp_dir!(), "cli_check_file_#{System.unique_integer([:positive])}.bean")

    File.write!(path, "2026-01-01 open Assets:Bank USD\n")
    on_exit(fn -> File.rm(path) end)

    assert {:ok, %Beancount.Result{status: :ok}} = Engine.CLI.check_file(path)
  end

  test "CLI engine query/2 delegates to Query" do
    Beancount.FakeBeanQuery.install!()

    assert {:ok, %Beancount.Query.Result{columns: ["account", "balance"]}} =
             Engine.CLI.query("2026-01-01 open Assets:Bank USD\n", "SELECT account, balance")
  end

  test "FakeEngine implements the engine behaviour" do
    assert Beancount.FakeEngine.render([]) == ""

    assert {:ok, %Beancount.Result{status: :ok}} =
             Beancount.FakeEngine.check("2026-01-01 open Assets:Bank USD\n")

    assert {:ok, %Beancount.Query.Result{status: :ok}} =
             Beancount.FakeEngine.query("ledger", "SELECT account")

    assert [{:check, :text}] = Beancount.FakeEngine.calls()
  end

  test "FakeEngine start_link/0 returns already_started when running" do
    assert {:error, {:already_started, _pid}} = Beancount.FakeEngine.start_link()
  end

  test "Beancount.check/1 dispatches through the configured engine" do
    original_engine = Application.get_env(:beancount_ex, :engine)
    Application.put_env(:beancount_ex, :engine, Beancount.FakeEngine)
    on_exit(fn -> Application.put_env(:beancount_ex, :engine, original_engine) end)

    ledger = [Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"])]

    assert {:ok, %Beancount.Result{status: :ok}} = Beancount.check(ledger)
    assert [{:check, :text}] = Beancount.FakeEngine.calls()
  end

  test "Beancount.check_file/1 dispatches through the configured engine" do
    original_engine = Application.get_env(:beancount_ex, :engine)

    Application.put_env(:beancount_ex, :engine, Beancount.FakeEngine)

    on_exit(fn ->
      Application.put_env(:beancount_ex, :engine, original_engine)
    end)

    path = Path.join(System.tmp_dir!(), "engine_test_#{System.unique_integer([:positive])}.bean")
    File.write!(path, "2026-01-01 open Assets:Bank USD\n")
    on_exit(fn -> File.rm(path) end)

    assert {:ok, %Beancount.Result{status: :ok}} = Beancount.check_file(path)
    assert [{:check_file, ^path}] = Beancount.FakeEngine.calls()
  end
end
