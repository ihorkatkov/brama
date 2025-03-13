defmodule Brama.ConnectionManagerTest do
  use ExUnit.Case

  alias Brama.ConnectionManager
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

  describe "connection registration" do
    test "registers a new connection" do
      assert {:ok, conn_data} = ConnectionManager.register("test_api")
      assert conn_data.identifier == "test_api"
      assert conn_data.state == :closed
      assert conn_data.failure_count == 0
    end

    test "registers a connection with scope" do
      assert {:ok, conn_data} = ConnectionManager.register("test_api", scope: "test_scope")
      assert conn_data.scope == "test_scope"
    end

    test "registers a connection with custom max_attempts" do
      assert {:ok, _} = ConnectionManager.register("test_api", max_attempts: 5)

      # Add failures up to the custom threshold
      ConnectionManager.failure("test_api")
      ConnectionManager.failure("test_api")
      ConnectionManager.failure("test_api")
      ConnectionManager.failure("test_api")
      assert {:ok, %{state: :closed}} = ConnectionManager.status("test_api")

      # One more failure should open the circuit
      ConnectionManager.failure("test_api")
      assert {:ok, %{state: :open}} = ConnectionManager.status("test_api")
    end

    test "registers a connection with custom expiry" do
      # This is a placeholder test - in a real implementation we'd need to
      # control time to properly test expiry
      assert {:ok, _} = ConnectionManager.register("test_api", expiry: 30_000)
    end

    test "returns error when registering duplicate connection" do
      assert {:ok, _} = ConnectionManager.register("test_api")
      assert {:error, :already_registered} = ConnectionManager.register("test_api")
    end
  end

  describe "connection status" do
    test "returns connection status" do
      ConnectionManager.register("test_api")
      assert {:ok, status} = ConnectionManager.status("test_api")
      assert status.state == :closed
    end

    test "returns error for unknown connection" do
      assert {:error, :not_found} = ConnectionManager.status("unknown_api")
    end

    test "checks if connection is available" do
      ConnectionManager.register("test_api")
      assert ConnectionManager.available?("test_api") == true
    end

    test "connection is available in closed state" do
      ConnectionManager.register("test_api")
      TestHelpers.set_state("test_api", :closed)
      assert ConnectionManager.available?("test_api") == true
    end

    test "connection is available in half-open state" do
      ConnectionManager.register("test_api")
      TestHelpers.set_state("test_api", :half_open)
      assert ConnectionManager.available?("test_api") == true
    end

    test "connection is not available in open state" do
      ConnectionManager.register("test_api")
      TestHelpers.set_state("test_api", :open)
      assert ConnectionManager.available?("test_api") == false
    end
  end

  describe "connection unregistration" do
    test "unregisters a connection" do
      ConnectionManager.register("test_api")
      assert :ok = ConnectionManager.unregister("test_api")
      assert {:error, :not_found} = ConnectionManager.status("test_api")
    end

    test "returns ok when unregistering unknown connection" do
      assert :ok = ConnectionManager.unregister("unknown_api")
    end
  end

  describe "success reporting" do
    test "reports success" do
      ConnectionManager.register("test_api")
      assert :ok = ConnectionManager.success("test_api")
    end

    test "resets failure count on success" do
      ConnectionManager.register("test_api")
      ConnectionManager.failure("test_api")
      ConnectionManager.success("test_api")
      assert {:ok, %{failure_count: 0}} = ConnectionManager.status("test_api")
    end

    test "transitions from half-open to closed on success" do
      ConnectionManager.register("test_api")
      TestHelpers.set_state("test_api", :half_open)
      ConnectionManager.success("test_api")
      TestHelpers.assert_circuit_closed("test_api")
    end

    test "does not change state on success in closed state" do
      ConnectionManager.register("test_api")
      ConnectionManager.success("test_api")
      TestHelpers.assert_circuit_closed("test_api")
    end
  end

  describe "failure reporting" do
    test "reports failure" do
      ConnectionManager.register("test_api")
      assert :ok = ConnectionManager.failure("test_api")
    end

    test "increments failure count" do
      ConnectionManager.register("test_api")
      ConnectionManager.failure("test_api")
      assert {:ok, %{failure_count: 1}} = ConnectionManager.status("test_api")
    end

    test "opens circuit after max failures" do
      ConnectionManager.register("test_api", max_attempts: 3)
      ConnectionManager.failure("test_api")
      ConnectionManager.failure("test_api")
      assert {:ok, %{state: :closed}} = ConnectionManager.status("test_api")
      ConnectionManager.failure("test_api")
      assert {:ok, %{state: :open}} = ConnectionManager.status("test_api")
    end

    test "immediately opens circuit on failure in half-open state" do
      ConnectionManager.register("test_api")
      TestHelpers.set_state("test_api", :half_open)
      ConnectionManager.failure("test_api")
      TestHelpers.assert_circuit_open("test_api")
    end

    test "records opened_at timestamp when opening circuit" do
      ConnectionManager.register("test_api", max_attempts: 1)
      ConnectionManager.failure("test_api")
      assert {:ok, %{state: :open, opened_at: timestamp}} = ConnectionManager.status("test_api")
      assert is_integer(timestamp)
    end
  end

  describe "manual circuit control" do
    test "manually opens circuit" do
      ConnectionManager.register("test_api")
      assert :ok = ConnectionManager.open_circuit!("test_api")
      TestHelpers.assert_circuit_open("test_api")
    end

    test "manually closes circuit" do
      ConnectionManager.register("test_api")
      ConnectionManager.open_circuit!("test_api")
      assert :ok = ConnectionManager.close_circuit!("test_api")
      TestHelpers.assert_circuit_closed("test_api")
    end

    test "resets circuit" do
      ConnectionManager.register("test_api")
      ConnectionManager.failure("test_api")
      ConnectionManager.failure("test_api")
      assert :ok = ConnectionManager.reset_circuit!("test_api")
      assert {:ok, %{state: :closed, failure_count: 0}} = ConnectionManager.status("test_api")
    end

    test "manually opens circuit with custom expiry" do
      ConnectionManager.register("test_api")
      assert :ok = ConnectionManager.open_circuit!("test_api", expires_in: 30_000)
      TestHelpers.assert_circuit_open("test_api")
    end
  end
end
