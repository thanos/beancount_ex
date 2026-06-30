defmodule Beancount.Parser.ErrorTest do
  use ExUnit.Case, async: true

  alias Beancount.Parser.Error

  test "exception/1 includes line and column in message" do
    assert %Error{message: message, line: 3, column: 5} =
             Error.exception(message: "bad token", line: 3, column: 5)

    assert message == "bad token at line 3, column 5"
  end

  test "exception/1 includes line only when column is absent" do
    assert %Error{message: message} = Error.exception(message: "bad token", line: 2)
    assert message == "bad token at line 2"
  end

  test "exception/1 uses default message when omitted" do
    assert %Error{message: "parse error"} = Error.exception([])
  end
end
