defmodule BramaTest do
  use ExUnit.Case
  doctest Brama

  test "greets the world" do
    assert Brama.hello() == :world
  end
end
