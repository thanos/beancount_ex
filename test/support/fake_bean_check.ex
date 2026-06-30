defmodule Beancount.FakeBeanCheck do
  @moduledoc false

  # Creates a fake `bean-check` executable so tests can exercise the real CLI
  # invocation path (System.cmd, output capture, exit-status handling) without
  # requiring a real Beancount installation.
  #
  # The fake fails any ledger whose text contains the token "FAIL" and succeeds
  # otherwise, letting tests drive both the {:ok, _} and {:error, _} branches.

  @doc "Create the fake executable and return its path."
  @spec create!() :: Path.t()
  def create! do
    dir = Path.join(System.tmp_dir!(), "fake_bean_check_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    script = Path.join(dir, "bean-check")

    File.write!(script, """
    #!/bin/sh
    if grep -q FAIL "$1"; then
      echo "$1:1: forced failure for tests"
      exit 1
    fi
    exit 0
    """)

    File.chmod!(script, 0o755)
    script
  end

  @doc """
  Configure the fake as the active `bean-check`, restoring the previous value
  when the calling test exits.
  """
  @spec install!() :: Path.t()
  def install! do
    original = Application.get_env(:beancount_ex, :bean_check_path)
    script = create!()
    Application.put_env(:beancount_ex, :bean_check_path, script)

    ExUnit.Callbacks.on_exit(fn ->
      Application.put_env(:beancount_ex, :bean_check_path, original)
    end)

    script
  end
end
