defmodule BeancountTest do
  use ExUnit.Case
  doctest Beancount

  test "greets the world" do
    assert Beancount.hello() == :world
  end
end
