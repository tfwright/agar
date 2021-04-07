defmodule AgarTest do
  use ExUnit.Case
  doctest Agar

  test "greets the world" do
    assert Agar.hello() == :world
  end
end
