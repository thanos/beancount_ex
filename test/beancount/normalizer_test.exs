defmodule Beancount.NormalizerTest do
  use ExUnit.Case, async: true

  alias Beancount.Normalizer

  doctest Beancount.Normalizer

  test "exit status 0 is :ok with no errors" do
    assert %{status: :ok, errors: []} = Normalizer.normalize(0, "", "")
  end

  test "non-zero exit status is :error" do
    assert %{status: :error} = Normalizer.normalize(1, "", "")
  end

  test "parses file:line: message format" do
    output = "/tmp/x.bean:12: Transaction does not balance"

    assert %{errors: [%{line: 12, message: "Transaction does not balance"}]} =
             Normalizer.normalize(1, output, "", "/tmp/x.bean")
  end

  test "strips the source path from messages for determinism" do
    output = "/tmp/abc.bean:1: error referencing /tmp/abc.bean again"
    %{errors: [error]} = Normalizer.normalize(1, output, "", "/tmp/abc.bean")
    refute error.message =~ "/tmp/abc.bean"
    assert error.message =~ "<input>"
  end

  test "lines without a line number are kept with nil line" do
    assert %{errors: [%{line: nil, message: "some freeform error"}]} =
             Normalizer.normalize(1, "some freeform error", "")
  end
end
