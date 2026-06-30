defmodule Beancount.EngineTest do
  use ExUnit.Case, async: false

  alias Beancount.Engine

  test "configured/0 returns the CLI engine by default" do
    assert Engine.configured() == Beancount.Engine.CLI
  end

  test "CLI engine render/1 delegates to the Renderer" do
    directives = [Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"])]
    assert Engine.CLI.render(directives) == Beancount.Renderer.render(directives)
  end

  test "Beancount.check_file/1 reads and dispatches through the engine" do
    Application.put_env(:beancount_ex, :bean_check_path, "definitely-not-a-real-binary-xyz")
    on_exit(fn -> Application.put_env(:beancount_ex, :bean_check_path, "bean-check") end)

    path = Path.join(System.tmp_dir!(), "engine_test_#{System.unique_integer([:positive])}.bean")
    File.write!(path, "2026-01-01 open Assets:Bank USD\n")
    on_exit(fn -> File.rm(path) end)

    assert_raise Beancount.Checker.NotInstalledError, fn -> Beancount.check_file(path) end
  end
end
