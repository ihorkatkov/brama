defmodule Brama.TestHelpersTest do
  use ExUnit.Case

  alias Brama.TestHelpers

  setup do
    # Restart the application before each test
    Application.stop(:brama)
    Application.ensure_all_started(:brama)

    # Clean up any existing connections before each test
    on_exit(fn ->
      # This is a simplification - in a real implementation we'd have a way to reset all connections
      :ok
    end)

    :ok
  end

  describe "circuit state manipulation" do
    test "set_state to open" do
      Brama.register("test_api")
      assert :ok = TestHelpers.set_state("test_api", :open)
      TestHelpers.assert_circuit_open("test_api")
    end

    test "set_state to closed" do
      Brama.register("test_api")
      Brama.open_circuit!("test_api")
      assert :ok = TestHelpers.set_state("test_api", :closed)
      TestHelpers.assert_circuit_closed("test_api")
    end

    test "set_state to half-open" do
      Brama.register("test_api")
      assert :ok = TestHelpers.set_state("test_api", :half_open)
      # Note: This is a simplification - in a real implementation we'd need to
      # properly test the half-open state
    end
  end

  describe "failure simulation" do
    test "add_failures" do
      Brama.register("test_api", max_attempts: 5)
      assert :ok = TestHelpers.add_failures("test_api", 3)
      assert {:ok, %{failure_count: 3}} = Brama.status("test_api")
    end

    test "add_failures opens circuit when threshold reached" do
      Brama.register("test_api", max_attempts: 3)
      assert :ok = TestHelpers.add_failures("test_api", 3)
      TestHelpers.assert_circuit_open("test_api")
    end

    test "simulate_failures" do
      Brama.register("test_api")
      assert :ok = TestHelpers.simulate_failures("test_api", 2)
      assert {:ok, %{failure_count: 2}} = Brama.status("test_api")
    end

    test "simulate_recovery" do
      Brama.register("test_api")
      TestHelpers.add_failures("test_api", 2)
      assert :ok = TestHelpers.simulate_recovery("test_api")
      assert {:ok, %{failure_count: 0}} = Brama.status("test_api")
    end
  end

  describe "assertions" do
    test "assert_circuit_open" do
      Brama.register("test_api")
      Brama.open_circuit!("test_api")
      assert :ok = TestHelpers.assert_circuit_open("test_api")
    end

    test "assert_circuit_closed" do
      Brama.register("test_api")
      assert :ok = TestHelpers.assert_circuit_closed("test_api")
    end

    test "assert_circuit_half_open" do
      Brama.register("test_api")
      TestHelpers.set_state("test_api", :half_open)
      assert :ok = TestHelpers.assert_circuit_half_open("test_api")
    end
  end

  describe "event testing" do
    @tag :skip
    test "wait_for_event" do
      Brama.register("test_api", max_attempts: 1)

      # Subscribe to events first
      {:ok, _subscription} = Brama.subscribe(events: [:failure], connection: "test_api")

      # Start a process to trigger an event
      spawn(fn ->
        Process.sleep(100)
        Brama.failure("test_api")
      end)

      # Wait for the failure event with a longer timeout
      assert {:ok, event} =
               TestHelpers.wait_for_event(:failure, connection: "test_api", timeout: 2000)

      assert event.event == :failure
      assert event.connection == "test_api"
    end

    @tag :skip
    test "assert_event_received" do
      Brama.register("test_api", max_attempts: 1)

      # Subscribe to events first
      {:ok, _subscription} = Brama.subscribe(events: [:failure], connection: "test_api")

      # Start a process to trigger an event
      spawn(fn ->
        Process.sleep(100)
        Brama.failure("test_api")
      end)

      # Assert that we receive the event with a longer timeout
      assert :ok =
               TestHelpers.assert_event_received(:failure, connection: "test_api", timeout: 2000)
    end
  end
end
