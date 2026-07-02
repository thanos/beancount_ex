defmodule Beancount.FakeBeanQuery do
  @moduledoc false

  # Creates a fake `bean-query` executable so tests can exercise the real CLI
  # invocation path (System.cmd, CSV parsing, exit-status handling) without a
  # real Beancount installation.
  #
  # Invoked as: bean-query -f csv <file> <bql>
  #
  # - If the BQL (last argument) contains "FAIL", it exits 1 with an error line.
  # - Otherwise it prints a fixed CSV table and exits 0.

  @csv ~s(account,balance\r\n) <>
         ~s(Assets:Bank,5000 USD\r\n) <>
         ~s("Income:Salary","-5000 USD"\r\n)

  # CSV rows passed to the fake script as separate printf arguments, so no shell
  # escape processing touches the quotes inside the cells.
  @csv_rows [
    "account,balance",
    "Assets:Bank,5000 USD",
    ~s("Income:Salary","-5000 USD")
  ]

  @doc "Create the fake executable and return its path."
  @spec create!() :: Path.t()
  def create! do
    dir = Path.join(System.tmp_dir!(), "fake_bean_query_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    script = Path.join(dir, "bean-query")

    # Cells are single-quoted literals fed to printf via a `%s\r\n` format, so
    # only the well-defined \r and \n escapes are interpreted (portable across
    # dash/bash). Any single quotes inside a cell are escaped for the shell.
    rows =
      @csv_rows
      |> Enum.map(fn row -> "'" <> String.replace(row, "'", ~S('\'')) <> "'" end)
      |> Enum.join(" ")

    File.write!(script, """
    #!/bin/sh
    # Last argument is the BQL query string.
    for arg in "$@"; do bql="$arg"; done
    case "$bql" in
      *FAIL*)
        echo "query error: forced failure for tests"
        exit 1
        ;;
      *)
        printf '%s\\r\\n' #{rows}
        exit 0
        ;;
    esac
    """)

    File.chmod!(script, 0o755)
    script
  end

  @doc """
  Configure the fake as the active `bean-query`, restoring the previous value
  when the calling test exits.
  """
  @spec install!() :: Path.t()
  def install! do
    original = Application.get_env(:beancount_ex, :bean_query_path)
    script = create!()
    Application.put_env(:beancount_ex, :bean_query_path, script)

    ExUnit.Callbacks.on_exit(fn ->
      Application.put_env(:beancount_ex, :bean_query_path, original)
    end)

    script
  end

  @doc "The CSV payload the fake emits on success."
  @spec csv() :: String.t()
  def csv, do: @csv
end
