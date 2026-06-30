defmodule Beancount.FakeBeanQueryTest do
  use ExUnit.Case, async: true

  alias Beancount.FakeBeanQuery

  test "create!/0 returns an executable path" do
    script = FakeBeanQuery.create!()
    on_exit(fn -> File.rm_rf!(Path.dirname(script)) end)

    assert File.regular?(script)
    {output, 0} = System.cmd(script, ["-f", "csv", "/dev/null", "SELECT account"])
    assert output =~ "account,balance"
  end

  test "csv/0 returns the fake success payload" do
    assert FakeBeanQuery.csv() =~ "account,balance"
    assert FakeBeanQuery.csv() =~ "Assets:Bank"
  end
end
