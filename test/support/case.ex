defmodule Brama.TestCase do
  @moduledoc """
  A test case for Brama.
  """

  use ExUnit.CaseTemplate

  setup do
    # Start the application if not started
    Application.ensure_all_started(:brama)

    on_exit(fn ->
      if pid = Process.whereis(Brama.ConnectionManager) do
        :sys.replace_state(pid, fn state -> %{state | connections: %{}} end)
      end
    end)

    :ok
  end
end
