defmodule Brama.ConnectionManager do
  @moduledoc """
  Manages connection states and implements circuit breaking logic.

  This module is responsible for:
  - Tracking connection states (closed, open, half-open)
  - Implementing circuit breaking logic
  - Managing state transitions
  - Cleaning up expired connections
  """
  use GenServer
  require Logger

  # Default values
  @default_max_attempts 5
  # 60 seconds
  @default_expiry 60_000
  # 10 seconds
  @default_cleanup_interval 10_000
  # 24 hours
  @default_inactive_threshold 86_400_000

  # Connection states
  @state_closed :closed
  @state_open :open
  @state_half_open :half_open

  @type connection_id :: String.t()
  @type connection_scope :: String.t() | nil
  @type connection_state :: :closed | :open | :half_open
  @type connection_data :: %{
          identifier: connection_id,
          scope: connection_scope,
          state: connection_state,
          failure_count: non_neg_integer(),
          max_attempts: pos_integer() | nil,
          expiry: non_neg_integer() | nil,
          opened_at: non_neg_integer() | nil,
          last_success_time: non_neg_integer() | nil,
          last_failure_time: non_neg_integer() | nil,
          metadata: map(),
          expiry_strategy: :fixed | :progressive,
          initial_expiry: non_neg_integer(),
          max_expiry: non_neg_integer(),
          backoff_factor: float()
        }

  # Client API

  @doc """
  Starts the connection manager.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Updates the configuration for a specific connection or globally.

  ## Parameters

  - `identifier` - Optional connection identifier. If not provided, updates global settings
  - `opts` - Configuration options to update
  """
  @spec configure(String.t() | nil, keyword()) :: :ok | {:error, term()}
  def configure(identifier \\ nil, opts) do
    GenServer.call(__MODULE__, {:configure, identifier, opts})
  end

  @doc """
  Registers a new connection.

  ## Options

  * `:scope` - Optional scope for grouping connections
  * `:max_attempts` - Maximum number of failures before opening circuit
  * `:expiry` - Time in milliseconds after which an open circuit transitions to half-open
  * `:metadata` - Additional metadata to store with the connection
  """
  @spec register(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def register(identifier, opts \\ []) do
    GenServer.call(__MODULE__, {:register, identifier, opts})
  end

  @doc """
  Unregisters a connection.

  ## Options

  * `:scope` - Optional scope to match
  """
  @spec unregister(String.t(), keyword()) :: :ok | {:error, term()}
  def unregister(identifier, opts \\ []) do
    GenServer.call(__MODULE__, {:unregister, identifier, opts})
  end

  @doc """
  Checks if a connection is available (circuit is closed or half-open).

  ## Options

  * `:scope` - Optional scope to match
  """
  @spec available?(String.t(), keyword()) :: boolean()
  def available?(identifier, opts \\ []) do
    case status(identifier, opts) do
      {:ok, %{state: @state_open}} -> false
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Reports a successful connection attempt.

  ## Options

  * `:scope` - Optional scope to match
  * `:metadata` - Additional metadata about the success
  """
  @spec success(String.t(), keyword()) :: :ok | {:error, term()}
  def success(identifier, opts \\ []) do
    GenServer.call(__MODULE__, {:success, identifier, opts})
  end

  @doc """
  Reports a failed connection attempt.

  ## Options

  * `:scope` - Optional scope to match
  * `:reason` - Reason for the failure
  * `:metadata` - Additional metadata about the failure
  """
  @spec failure(String.t(), keyword()) :: :ok | {:error, term()}
  def failure(identifier, opts \\ []) do
    GenServer.call(__MODULE__, {:failure, identifier, opts})
  end

  @doc """
  Gets the current status of a connection.

  ## Options

  * `:scope` - Optional scope to match
  """
  @spec status(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def status(identifier, opts \\ []) do
    GenServer.call(__MODULE__, {:status, identifier, opts})
  end

  @doc """
  Manually opens the circuit for a connection.

  ## Options

  * `:scope` - Optional scope to match
  * `:reason` - Reason for opening the circuit
  * `:expiry` - Custom expiry time in milliseconds
  """
  @spec open_circuit!(String.t(), keyword()) :: :ok | {:error, term()}
  def open_circuit!(identifier, opts \\ []) do
    GenServer.call(__MODULE__, {:open_circuit, identifier, opts})
  end

  @doc """
  Manually closes the circuit for a connection.

  ## Options

  * `:scope` - Optional scope to match
  """
  @spec close_circuit!(String.t(), keyword()) :: :ok | {:error, term()}
  def close_circuit!(identifier, opts \\ []) do
    GenServer.call(__MODULE__, {:close_circuit, identifier, opts})
  end

  @doc """
  Resets the circuit for a connection (closes it and resets failure count).

  ## Options

  * `:scope` - Optional scope to match
  """
  @spec reset_circuit!(String.t(), keyword()) :: :ok | {:error, term()}
  def reset_circuit!(identifier, opts \\ []) do
    GenServer.call(__MODULE__, {:reset_circuit, identifier, opts})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    # Initialize the connection registry with configuration
    state = %{
      connections: %{},
      config: %{
        max_attempts: Keyword.get(opts, :max_attempts, @default_max_attempts),
        expiry: Keyword.get(opts, :expiry, @default_expiry),
        cleanup_interval: Keyword.get(opts, :cleanup_interval, @default_cleanup_interval),
        inactive_threshold: Keyword.get(opts, :inactive_threshold, @default_inactive_threshold)
      }
    }

    # Schedule cleanup
    schedule_cleanup()

    {:ok, state}
  end

  @impl true
  def handle_call({:configure, nil, opts}, _from, state) do
    # Update global configuration
    new_config = Map.merge(state.config, Map.new(opts))
    {:reply, :ok, %{state | config: new_config}}
  end

  @impl true
  def handle_call({:configure, identifier, opts}, _from, state) do
    scope = Keyword.get(opts, :scope)
    key = connection_key(identifier, scope)

    case Map.get(state.connections, key) do
      nil ->
        {:reply, {:error, :not_found}, state}

      connection ->
        # Update connection configuration
        updated_connection = %{
          connection
          | max_attempts: Keyword.get(opts, :max_attempts, connection.max_attempts),
            expiry: Keyword.get(opts, :expiry, connection.expiry),
            expiry_strategy: Keyword.get(opts, :expiry_strategy, :fixed),
            initial_expiry: Keyword.get(opts, :initial_expiry, connection.expiry),
            max_expiry: Keyword.get(opts, :max_expiry, connection.expiry * 10),
            backoff_factor: Keyword.get(opts, :backoff_factor, 2.0)
        }

        new_state = put_in(state.connections[key], updated_connection)
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:register, identifier, opts}, _from, state) do
    scope = Keyword.get(opts, :scope)
    key = connection_key(identifier, scope)

    if Map.has_key?(state.connections, key) do
      {:reply, {:error, :already_registered}, state}
    else
      # Create new connection data
      connection_data = %{
        identifier: identifier,
        scope: scope,
        state: @state_closed,
        failure_count: 0,
        max_attempts: Keyword.get(opts, :max_attempts, state.config.max_attempts),
        expiry: Keyword.get(opts, :expiry, state.config.expiry),
        opened_at: nil,
        last_success_time: nil,
        last_failure_time: nil,
        metadata: Keyword.get(opts, :metadata, %{}),
        expiry_strategy: Keyword.get(opts, :expiry_strategy, :fixed),
        initial_expiry: Keyword.get(opts, :initial_expiry, state.config.expiry),
        max_expiry: Keyword.get(opts, :max_expiry, state.config.expiry * 10),
        backoff_factor: Keyword.get(opts, :backoff_factor, 2.0)
      }

      # Store the connection
      new_state = put_in(state.connections[key], connection_data)

      # Notify about the registration
      notify_event(:registration, identifier, scope, connection_data)

      {:reply, {:ok, connection_data}, new_state}
    end
  end

  @impl true
  def handle_call({:unregister, identifier, opts}, _from, state) do
    scope = Keyword.get(opts, :scope)
    key = connection_key(identifier, scope)

    if Map.has_key?(state.connections, key) do
      # Get the connection data before removing
      connection_data = state.connections[key]

      # Remove the connection
      new_state = update_in(state.connections, &Map.delete(&1, key))

      # Notify about the unregistration
      notify_event(:connection_unregistered, identifier, scope, connection_data)

      {:reply, :ok, new_state}
    else
      # Connection not found, but we'll return :ok anyway
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:status, identifier, opts}, _from, state) do
    scope = Keyword.get(opts, :scope)
    key = connection_key(identifier, scope)

    if Map.has_key?(state.connections, key) do
      {:reply, {:ok, state.connections[key]}, state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:success, identifier, opts}, _from, state) do
    scope = Keyword.get(opts, :scope)
    key = connection_key(identifier, scope)

    if Map.has_key?(state.connections, key) do
      connection_data = state.connections[key]

      # Update connection data
      updated_data = %{
        connection_data
        | failure_count: 0,
          last_success_time: System.system_time(:millisecond)
      }

      # Check if we need to transition from half-open to closed
      {updated_data, event} =
        if connection_data.state == @state_half_open do
          # Transition to closed state
          {%{updated_data | state: @state_closed}, :circuit_closed}
        else
          # No state change
          {updated_data, :success}
        end

      # Store the updated connection
      new_state = put_in(state.connections[key], updated_data)

      # Notify about the success
      notify_event(event, identifier, scope, updated_data)

      {:reply, :ok, new_state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:failure, identifier, opts}, _from, state) do
    scope = Keyword.get(opts, :scope)
    key = connection_key(identifier, scope)

    if Map.has_key?(state.connections, key) do
      connection_data = state.connections[key]

      # Get the reason if provided
      reason = Keyword.get(opts, :reason)

      # Update failure count and timestamp
      updated_data = %{
        connection_data
        | failure_count: connection_data.failure_count + 1,
          last_failure_time: System.system_time(:millisecond)
      }

      # Check if we need to open the circuit
      {updated_data, event} =
        cond do
          # If already in half-open state, any failure opens the circuit
          connection_data.state == @state_half_open ->
            now = System.system_time(:millisecond)
            {%{updated_data | state: @state_open, opened_at: now}, :circuit_opened}

          # If failure count exceeds threshold, open the circuit
          connection_data.max_attempts &&
              updated_data.failure_count >= connection_data.max_attempts ->
            now = System.system_time(:millisecond)
            {%{updated_data | state: @state_open, opened_at: now}, :circuit_opened}

          # Otherwise, just record the failure
          true ->
            {updated_data, :failure}
        end

      # Store the updated connection
      new_state = put_in(state.connections[key], updated_data)

      # Notify about the failure
      notify_event(event, identifier, scope, %{
        updated_data
        | metadata: Map.put(updated_data.metadata || %{}, :reason, reason)
      })

      {:reply, :ok, new_state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:open_circuit, identifier, opts}, _from, state) do
    scope = Keyword.get(opts, :scope)
    key = connection_key(identifier, scope)

    if Map.has_key?(state.connections, key) do
      connection_data = state.connections[key]

      # Get custom expiry if provided, otherwise calculate based on strategy
      expiry = Keyword.get(opts, :expiry) || calculate_expiry(connection_data)

      # Update connection data
      now = System.system_time(:millisecond)
      updated_data = %{connection_data | state: @state_open, opened_at: now, expiry: expiry}

      # Store the updated connection
      new_state = put_in(state.connections[key], updated_data)

      # Notify about the circuit opening
      reason = Keyword.get(opts, :reason, "Manually opened")

      notify_event(:circuit_opened, identifier, scope, %{
        updated_data
        | metadata: Map.put(updated_data.metadata || %{}, :reason, reason)
      })

      {:reply, :ok, new_state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:close_circuit, identifier, opts}, _from, state) do
    scope = Keyword.get(opts, :scope)
    key = connection_key(identifier, scope)

    if Map.has_key?(state.connections, key) do
      connection_data = state.connections[key]

      # Update connection data
      updated_data = %{connection_data | state: @state_closed}

      # Store the updated connection
      new_state = put_in(state.connections[key], updated_data)

      # Notify about the circuit closing
      reason = Keyword.get(opts, :reason, "Manually closed")

      notify_event(:circuit_closed, identifier, scope, %{
        updated_data
        | metadata: Map.put(updated_data.metadata || %{}, :reason, reason)
      })

      {:reply, :ok, new_state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:reset_circuit, identifier, opts}, _from, state) do
    scope = Keyword.get(opts, :scope)
    key = connection_key(identifier, scope)

    if Map.has_key?(state.connections, key) do
      connection_data = state.connections[key]

      # Update connection data
      updated_data = %{connection_data | state: @state_closed, failure_count: 0}

      # Store the updated connection
      new_state = put_in(state.connections[key], updated_data)

      # Notify about the circuit reset
      reason = Keyword.get(opts, :reason, "Manually reset")

      notify_event(:circuit_reset, identifier, scope, %{
        updated_data
        | metadata: Map.put(updated_data.metadata || %{}, :reason, reason)
      })

      {:reply, :ok, new_state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.system_time(:millisecond)
    new_connections = cleanup_connections(state.connections, now, state.config)

    # Schedule next cleanup
    schedule_cleanup()

    # Notify about cleanup
    notify_event(:cleanup, "", nil, %{
      connections: Map.keys(new_connections),
      timestamp: now
    })

    {:noreply, %{state | connections: new_connections}}
  end

  # Helper functions

  @spec connection_key(connection_id(), keyword() | String.t() | nil) :: connection_id()
  defp connection_key(identifier, nil), do: identifier
  defp connection_key(identifier, scope) when is_binary(scope), do: "#{scope}:#{identifier}"

  defp connection_key(identifier, opts) when is_list(opts),
    do: connection_key(identifier, Keyword.get(opts, :scope))

  # Send event notification
  @spec notify_event(atom(), connection_id(), keyword() | String.t() | nil, map()) :: :ok
  defp notify_event(event_type, identifier, scope, data) when is_list(scope) do
    # Extract scope from keyword list if present
    actual_scope = Keyword.get(scope, :scope)
    notify_event(event_type, identifier, actual_scope, data)
  end

  defp notify_event(event_type, identifier, scope, data) do
    # Send to event dispatcher
    Brama.EventDispatcher.dispatch(event_type, identifier, scope, data)
  end

  @spec schedule_cleanup() :: :ok
  defp schedule_cleanup do
    Process.send_after(
      self(),
      :cleanup,
      Application.get_env(:brama, :cleanup_interval, @default_cleanup_interval)
    )

    :ok
  end

  @spec cleanup_connections(map(), non_neg_integer(), map()) :: map()
  defp cleanup_connections(connections, now, config) do
    Logger.debug("Starting cleanup with #{map_size(connections)} connections")

    result =
      Enum.reduce(connections, connections, fn {key, connection}, acc ->
        Logger.debug("Processing connection #{key} in state #{connection.state}")

        cond do
          # Check for inactive connections
          inactive?(connection, now, config.inactive_threshold) ->
            Logger.debug("Connection #{key} is inactive")
            # Notify about the removal
            notify_event(:connection_removed, connection.identifier, connection.scope, connection)
            Map.delete(acc, key)

          # Check for expiry and update state if needed
          connection.state == @state_open && connection.opened_at &&
              now - connection.opened_at >= connection.expiry ->
            Logger.debug("Connection #{key} is expired, transitioning to half-open")
            # Transition to half-open
            updated_connection = %{connection | state: @state_half_open}
            # Notify about the state change
            notify_event(
              :circuit_half_opened,
              connection.identifier,
              connection.scope,
              updated_connection
            )

            Map.put(acc, key, updated_connection)

          true ->
            Logger.debug("Connection #{key} remains unchanged")
            acc
        end
      end)

    Logger.debug("Cleanup finished with #{map_size(result)} connections")
    result
  end

  @spec inactive?(map(), non_neg_integer(), non_neg_integer()) :: boolean()
  defp inactive?(connection, now, threshold) do
    last_activity =
      Enum.max([
        connection.last_success_time || 0,
        connection.last_failure_time || 0,
        connection.opened_at || 0
      ])

    now - last_activity > threshold
  end

  @spec calculate_expiry(map()) :: non_neg_integer()
  defp calculate_expiry(connection) do
    case connection.expiry_strategy do
      :progressive ->
        # Calculate progressive expiry based on failure count
        initial = connection.initial_expiry
        max = connection.max_expiry
        factor = connection.backoff_factor
        failures = connection.failure_count

        # Calculate: initial * (factor ^ failures), capped at max
        (initial * :math.pow(factor, failures))
        |> min(max)
        |> trunc()

      :fixed ->
        connection.expiry
    end
  end
end
