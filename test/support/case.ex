defmodule Brama.TestCase do
  @moduledoc """
  A test case for Brama.
  """

  use ExUnit.CaseTemplate

  setup do
    on_exit(fn ->
      pid = Process.whereis(Brama.ConnectionManager)
      :sys.replace_state(pid, fn state -> %{state | connections: %{}} end)
    end)
  end
end
