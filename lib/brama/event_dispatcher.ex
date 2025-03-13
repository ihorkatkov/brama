defmodule Brama.EventDispatcher do
  @moduledoc """
  Handles event dispatching and subscription management for Brama.

  This module is responsible for:
  - Maintaining a registry of event subscribers
  - Filtering events based on subscriber preferences
  - Dispatching events to interested subscribers
  """
  use GenServer
  require Logger

  @registry Brama.Registry.Event

  # Event types
  @event_types [
    :state_change,
    :registration,
    :failure,
    :success,
    :expiry,
    :cleanup,
    :circuit_opened,
    :circuit_closed,
    :circuit_reset,
    :connection_registered,
    :connection_unregistered
  ]

  # Client API

  @doc """
  Starts the event dispatcher.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Subscribes to Brama events.

  ## Options

  * `:events` - List of event types to subscribe to (default: all)
  * `:connection` - Connection identifier to filter by (default: all)
  * `:scope` - Connection scope to filter by (default: all)
  """
  @spec subscribe(Keyword.t()) :: {:ok, reference()} | {:error, term()}
  def subscribe(opts \\ []) do
    filters = %{
      events: Keyword.get(opts, :events),
      connection: Keyword.get(opts, :connection),
      scope: Keyword.get(opts, :scope)
    }

    # Store subscriber with filters
    key = self()
    value = filters

    case Registry.register(@registry, key, value) do
      {:ok, _pid} -> {:ok, key}
      error -> error
    end
  end

  @doc """
  Unsubscribes from Brama events.
  """
  @spec unsubscribe(Keyword.t()) :: :ok | {:error, term()}
  def unsubscribe(_opts \\ []) do
    # Current process is the key
    Registry.unregister(@registry, self())
  end

  @doc """
  Dispatches an event to all matching subscribers.

  This function constructs an event map and notifies all subscribers
  whose filters match the event.
  """
  @spec dispatch(atom(), String.t(), String.t() | nil, map()) :: :ok
  def dispatch(event_type, connection, scope, data) when event_type in @event_types do
    event = %{
      event: event_type,
      timestamp: System.monotonic_time(:millisecond),
      connection: connection,
      scope: scope,
      data: data
    }

    GenServer.cast(__MODULE__, {:dispatch, event})

    # Also emit telemetry events
    :telemetry.execute(
      [:brama, :connection, event_type],
      %{system_time: System.system_time()},
      %{connection: connection, scope: scope, data: data}
    )

    :ok
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:dispatch, event}, state) do
    # Get all subscribers
    subscribers = Registry.select(@registry, [{{:"$1", :_, :"$2"}, [], [{{:"$1", :"$2"}}]}])

    # Dispatch event to each matching subscriber
    Enum.each(subscribers, fn {pid, filters} ->
      if matches_filters?(event, filters) do
        try do
          Process.send(pid, {:brama_event, event}, [:noconnect])
        rescue
          _ -> :ok
        end
      end
    end)

    {:noreply, state}
  end

  # Helper functions

  @spec matches_filters?(map(), map()) :: boolean()
  defp matches_filters?(event, filters) do
    matches_event_type?(event.event, filters.events) and
      matches_connection?(event.connection, filters.connection) and
      matches_scope?(event.scope, filters.scope)
  end

  @spec matches_event_type?(atom(), list() | nil) :: boolean()
  defp matches_event_type?(_event_type, nil), do: true

  defp matches_event_type?(event_type, event_list) when is_list(event_list) do
    Enum.member?(event_list, event_type)
  end

  @spec matches_connection?(String.t(), String.t() | nil) :: boolean()
  defp matches_connection?(_connection, nil), do: true

  defp matches_connection?(connection, filter) when is_binary(connection) and is_binary(filter) do
    connection == filter
  end

  @spec matches_scope?(String.t() | nil, String.t() | nil) :: boolean()
  defp matches_scope?(_scope, nil), do: true
  defp matches_scope?(nil, _filter), do: false

  defp matches_scope?(scope, filter) when is_binary(scope) and is_binary(filter) do
    scope == filter
  end
end
