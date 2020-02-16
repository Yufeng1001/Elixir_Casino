defmodule ElixirProjectTest do
  use ExUnit.Case
  doctest ElixirProject

  test "greets the world" do
    assert ElixirProject.hello() == :world
  end
end
