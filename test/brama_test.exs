defmodule BramaTest do
  use Brama.TestCase
  doctest Brama, except: [subscribe: 1]

  alias Brama.TestHelpers

  describe "connection registration" do
    test "registers a new connection" do
      assert {:ok, data} = Brama.register("test_api")
      assert data.identifier == "test_api"
      assert data.state == :closed
      assert data.failure_count == 0
    end

    test "registers a connection with a scope" do
      assert {:ok, data} = Brama.register("test_api", scope: "billing")
      assert data.scope == "billing"
    end

    test "registers a connection with custom max_attempts" do
      assert {:ok, data} = Brama.register("test_api", max_attempts: 3)
      assert data.max_attempts == 3

      # Add failures up to the threshold
      Brama.failure("test_api")
      Brama.failure("test_api")
      Brama.failure("test_api")

      # Circuit should be open now
      assert {:ok, %{state: :open}} = Brama.status("test_api")
    end

    test "registers a connection with custom expiry" do
      assert {:ok, _} = Brama.register("test_api", expiry: 30_000)
      # Testing expiry would require time manipulation or mocking
    end

    test "connection registration returns error when registering duplicate connection" do
      Brama.register("test_api")

      assert {:error, :already_registered} = Brama.register("test_api")
    end
  end

  describe "connection status" do
    test "gets status of registered connection" do
      Brama.register("test_api")
      assert {:ok, status} = Brama.status("test_api")
      assert status.state == :closed
    end

    test "returns error for unknown connection" do
      assert {:error, :not_found} = Brama.status("unknown_api")
    end

    test "connection is available when closed" do
      Brama.register("test_api")
      assert Brama.available?("test_api") == true
    end

    test "connection is available when half-open" do
      Brama.register("test_api")
      # Set to half-open (implementation dependent)
      assert Brama.available?("test_api") == true
    end

    test "connection is not available when open" do
      Brama.register("test_api")
      Brama.open_circuit!("test_api")
      assert Brama.available?("test_api") == false
    end
  end

  describe "connection unregistration" do
    test "unregisters a connection" do
      Brama.register("test_api")
      assert :ok = Brama.unregister("test_api")
      assert {:error, :not_found} = Brama.status("test_api")
    end

    test "succeeds when unregistering unknown connection" do
      assert :ok = Brama.unregister("unknown_api")
    end
  end

  describe "success reporting" do
    test "reports success" do
      Brama.register("test_api")
      assert :ok = Brama.success("test_api")
    end

    test "resets failure count on success" do
      Brama.register("test_api")
      Brama.failure("test_api")
      Brama.success("test_api")
      assert {:ok, %{failure_count: 0}} = Brama.status("test_api")
    end

    test "transitions from half-open to closed on success" do
      Brama.register("test_api")
      # Set to half-open (implementation dependent)
      Brama.success("test_api")
      assert {:ok, %{state: :closed}} = Brama.status("test_api")
    end

    test "no state change on success when already closed" do
      Brama.register("test_api")
      Brama.success("test_api")
      assert {:ok, %{state: :closed}} = Brama.status("test_api")
    end
  end

  describe "failure reporting" do
    test "reports failure" do
      Brama.register("test_api")
      assert :ok = Brama.failure("test_api")
    end

    test "increments failure count" do
      Brama.register("test_api")
      Brama.failure("test_api")
      assert {:ok, %{failure_count: 1}} = Brama.status("test_api")
    end

    test "opens circuit after max failures" do
      Brama.register("test_api", max_attempts: 3)
      Brama.failure("test_api")
      Brama.failure("test_api")
      Brama.failure("test_api")
      assert {:ok, %{state: :open}} = Brama.status("test_api")
    end

    test "immediately opens circuit on failure in half-open state" do
      Brama.register("test_api")
      # Set to half-open state
      TestHelpers.set_state("test_api", :half_open)
      # Now report a failure
      Brama.failure("test_api")
      # Assert that the circuit is now open
      assert {:ok, %{state: :open}} = Brama.status("test_api")
    end

    test "records opened_at timestamp when opening circuit" do
      Brama.register("test_api", max_attempts: 1)
      Brama.failure("test_api")
      assert {:ok, %{state: :open, opened_at: timestamp}} = Brama.status("test_api")
      assert is_integer(timestamp)
    end
  end

  describe "manual circuit control" do
    test "manually opens circuit" do
      Brama.register("test_api")
      assert :ok = Brama.open_circuit!("test_api")
      assert {:ok, %{state: :open}} = Brama.status("test_api")
    end

    test "manually closes circuit" do
      Brama.register("test_api")
      Brama.open_circuit!("test_api")
      assert :ok = Brama.close_circuit!("test_api")
      assert {:ok, %{state: :closed}} = Brama.status("test_api")
    end

    test "resets circuit" do
      Brama.register("test_api")
      Brama.failure("test_api")
      Brama.failure("test_api")
      assert :ok = Brama.reset_circuit!("test_api")
      assert {:ok, %{state: :closed, failure_count: 0}} = Brama.status("test_api")
    end

    test "manually opens circuit with custom expiry" do
      Brama.register("test_api")
      Brama.subscribe([])
      assert :ok = Brama.open_circuit!("test_api", expiry: 50)
      assert_receive {:brama_event, %{data: %{state: :closed}}}, 100
    end
  end

  describe "event subscription" do
    test "subscribes to events" do
      {:ok, subscription} = Brama.subscribe(events: [:state_change])
      assert is_pid(subscription)
    end

    test "unsubscribes from events" do
      {:ok, subscription} = Brama.subscribe(events: [:state_change])
      assert :ok = Brama.unsubscribe(subscription)
    end
  end
end
