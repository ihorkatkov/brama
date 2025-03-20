defmodule Brama.EventDispatcherTest do
  use Brama.TestCase

  alias Brama.EventDispatcher

  setup do
    # Unsubscribe after each test to avoid interference
    on_exit(fn ->
      try do
        EventDispatcher.unsubscribe()
      rescue
        _ -> :ok
      end
    end)

    :ok
  end

  describe "event subscription" do
    test "subscribes to events" do
      assert {:ok, _ref} = EventDispatcher.subscribe()
    end

    test "unsubscribes from events" do
      EventDispatcher.subscribe()
      assert :ok = EventDispatcher.unsubscribe()
    end
  end

  describe "event dispatching" do
    test "dispatches events to subscribers" do
      EventDispatcher.subscribe()

      # Dispatch an event
      EventDispatcher.dispatch(:state_change, "test_api", nil, %{
        previous_state: :closed,
        new_state: :open,
        reason: "Test"
      })

      # Check that we received the event
      assert_receive {:brama_event, event}, 1000
      assert event.event == :state_change
      assert event.connection == "test_api"
      assert event.data.previous_state == :closed
      assert event.data.new_state == :open
    end

    test "filters events by type" do
      EventDispatcher.subscribe(events: [:state_change])

      # Dispatch a matching event
      EventDispatcher.dispatch(:state_change, "test_api", nil, %{})

      # Dispatch a non-matching event
      EventDispatcher.dispatch(:registration, "test_api", nil, %{})

      # Check that we only received the matching event
      assert_receive {:brama_event, event}, 1000
      assert event.event == :state_change

      # Make sure we don't receive the non-matching event
      refute_receive {:brama_event, %{event: :registration}}, 100
    end

    test "filters events by connection" do
      EventDispatcher.subscribe(connection: "test_api")

      # Dispatch a matching event
      EventDispatcher.dispatch(:state_change, "test_api", nil, %{})

      # Dispatch a non-matching event
      EventDispatcher.dispatch(:state_change, "other_api", nil, %{})

      # Check that we only received the matching event
      assert_receive {:brama_event, event}, 1000
      assert event.connection == "test_api"

      # Make sure we don't receive the non-matching event
      refute_receive {:brama_event, %{connection: "other_api"}}, 100
    end

    test "filters events by scope" do
      EventDispatcher.subscribe(scope: "test_scope")

      # Dispatch a matching event
      EventDispatcher.dispatch(:state_change, "test_api", "test_scope", %{})

      # Dispatch a non-matching event
      EventDispatcher.dispatch(:state_change, "test_api", "other_scope", %{})

      # Check that we only received the matching event
      assert_receive {:brama_event, event}, 1000
      assert event.scope == "test_scope"

      # Make sure we don't receive the non-matching event
      refute_receive {:brama_event, %{scope: "other_scope"}}, 100
    end

    test "combines multiple filters" do
      EventDispatcher.subscribe(
        events: [:state_change],
        connection: "test_api",
        scope: "test_scope"
      )

      # Dispatch a fully matching event
      EventDispatcher.dispatch(:state_change, "test_api", "test_scope", %{})

      # Dispatch events that don't match all criteria
      EventDispatcher.dispatch(:registration, "test_api", "test_scope", %{})
      EventDispatcher.dispatch(:state_change, "other_api", "test_scope", %{})
      EventDispatcher.dispatch(:state_change, "test_api", "other_scope", %{})

      # Check that we only received the fully matching event
      assert_receive {:brama_event, event}, 1000
      assert event.event == :state_change
      assert event.connection == "test_api"
      assert event.scope == "test_scope"

      # Make sure we don't receive the non-matching events
      refute_receive {:brama_event, _}, 100
    end
  end
end
