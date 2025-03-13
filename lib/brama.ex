defmodule Brama do
  @moduledoc """
  Brama is a library for managing connections to external dependencies.

  It provides features for:
  - Connection monitoring
  - Circuit breaking
  - Self-healing
  - Status notifications

  ## Connection Management


  Brama allows you to register connections to external services and track their status:

  ```elixir
  # Register a connection
  Brama.register("payment_api")

  # Check if a connection is available
  Brama.available?("payment_api")

  # Report success/failure
  Brama.success("payment_api")
  Brama.failure("payment_api", reason: "Timeout")
  ```

  ## Circuit Breaking

  Brama implements the circuit breaker pattern to prevent cascading failures:

  ```elixir
  # Circuit opens automatically after consecutive failures
  Brama.failure("payment_api", reason: "Timeout") # After max_attempts, circuit opens

  # Manual circuit control
  Brama.open_circuit!("payment_api", reason: "Maintenance")
  Brama.close_circuit!("payment_api")
  Brama.reset_circuit!("payment_api")
  ```

  ## Event Subscription

  Subscribe to events to get notified of state changes:

  ```elixir
  # Subscribe to all events for a specific connection
  Brama.subscribe(connection: "payment_api")

  # Subscribe to specific event types
  Brama.subscribe(events: [:state_change, :failure])

  # Subscribe with a filter function
  Brama.subscribe(filter: fn event -> event.connection == "payment_api" end)
  ```
  """

  alias Brama.ConnectionManager
  alias Brama.EventDispatcher

  @doc """
  Registers a new connection with Brama.

  ## Parameters

  - `identifier`: A unique identifier for the connection
  - `opts`: Options for the connection
    - `:scope`: Optional scope for grouping connections
    - `:max_attempts`: Maximum number of failures before opening the circuit (default: 5)
    - `:expiry`: Time in milliseconds after which an open circuit transitions to half-open (default: 60000)
    - `:metadata`: Additional metadata to store with the connection

  ## Examples

  ```elixir
  iex> {:ok, result} = Brama.register("payment_api")
  iex> Map.take(result, [:identifier, :state, :failure_count])
  %{identifier: "payment_api", state: :closed, failure_count: 0}

  iex> {:ok, result} = Brama.register("invoice_api", scope: "billing", max_attempts: 5)
  iex> Map.take(result, [:identifier, :scope, :state, :failure_count])
  %{identifier: "invoice_api", scope: "billing", state: :closed, failure_count: 0}
  ```
  """
  def register(identifier, opts \\ []) do
    ConnectionManager.register(identifier, opts)
  end

  @doc """
  Unregisters a connection from Brama.

  ## Parameters

  - `identifier`: The connection identifier
  - `opts`: Options
    - `:scope`: Optional scope to match

  ## Examples

  ```elixir
  iex> Brama.register("payment_api")
  iex> Brama.unregister("payment_api")
  :ok
  ```
  """
  def unregister(identifier, opts \\ []) do
    ConnectionManager.unregister(identifier, opts)
  end

  @doc """
  Checks if a connection is available (circuit is closed or half-open).

  ## Parameters

  - `identifier`: The connection identifier
  - `opts`: Options
    - `:scope`: Optional scope to match

  ## Examples

  ```elixir
  iex> Brama.register("payment_api")
  iex> Brama.available?("payment_api")
  true
  ```
  """
  def available?(identifier, opts \\ []) do
    ConnectionManager.available?(identifier, opts)
  end

  @doc """
  Reports a successful connection attempt.

  ## Parameters

  - `identifier`: The connection identifier
  - `opts`: Options
    - `:scope`: Optional scope to match
    - `:metadata`: Additional metadata about the success

  ## Examples

  ```elixir
  iex> Brama.register("payment_api")
  iex> Brama.success("payment_api")
  :ok
  ```
  """
  def success(identifier, opts \\ []) do
    ConnectionManager.success(identifier, opts)
  end

  @doc """
  Reports a failed connection attempt.

  ## Parameters

  - `identifier`: The connection identifier
  - `opts`: Options
    - `:scope`: Optional scope to match
    - `:reason`: Reason for the failure
    - `:metadata`: Additional metadata about the failure

  ## Examples

  ```elixir
  iex> Brama.register("payment_api")
  iex> Brama.failure("payment_api", reason: "Timeout")
  :ok
  ```
  """
  def failure(identifier, opts \\ []) do
    ConnectionManager.failure(identifier, opts)
  end

  @doc """
  Gets the current status of a connection.

  ## Parameters

  - `identifier`: The connection identifier
  - `opts`: Options
    - `:scope`: Optional scope to match

  ## Examples

  ```elixir
  iex> Brama.register("payment_api")
  iex> {:ok, result} = Brama.status("payment_api")
  iex> Map.take(result, [:state, :failure_count])
  %{state: :closed, failure_count: 0}
  ```
  """
  def status(identifier, opts \\ []) do
    ConnectionManager.status(identifier, opts)
  end

  @doc """
  Manually opens the circuit for a connection.

  ## Parameters

  - `identifier`: The connection identifier
  - `opts`: Options
    - `:scope`: Optional scope to match
    - `:reason`: Reason for opening the circuit
    - `:expiry`: Custom expiry time in milliseconds

  ## Examples

  ```elixir
  iex> Brama.register("payment_api")
  iex> Brama.open_circuit!("payment_api", reason: "Maintenance")
  :ok
  ```
  """
  def open_circuit!(identifier, opts \\ []) do
    ConnectionManager.open_circuit!(identifier, opts)
  end

  @doc """
  Manually closes the circuit for a connection.

  ## Parameters

  - `identifier`: The connection identifier
  - `opts`: Options
    - `:scope`: Optional scope to match

  ## Examples

  ```elixir
  iex> Brama.register("payment_api")
  iex> Brama.close_circuit!("payment_api")
  :ok
  ```
  """
  def close_circuit!(identifier, opts \\ []) do
    ConnectionManager.close_circuit!(identifier, opts)
  end

  @doc """
  Resets the circuit for a connection (closes it and resets failure count).

  ## Parameters

  - `identifier`: The connection identifier
  - `opts`: Options
    - `:scope`: Optional scope to match

  ## Examples

  ```elixir
  iex> Brama.register("payment_api")
  iex> Brama.reset_circuit!("payment_api")
  :ok
  ```
  """
  def reset_circuit!(identifier, opts \\ []) do
    ConnectionManager.reset_circuit!(identifier, opts)
  end

  @doc """
  Subscribes to connection events.

  ## Parameters

  - `opts`: Subscription options (at least one must be provided)
    - `:connection`: Filter events by connection identifier
    - `:scope`: Filter events by connection scope
    - `:events`: List of event types to subscribe to
    - `:filter`: Custom filter function

  ## Examples

  ```elixir
  iex> Brama.subscribe(events: [:state_change])
  {:ok, pid}
  ```
  """
  def subscribe(opts) do
    EventDispatcher.subscribe(opts)
  end

  @doc """
  Unsubscribes from connection events.

  ## Parameters

  - `subscription_id`: The subscription ID returned from subscribe/1

  ## Examples

  ```elixir
  iex> {:ok, subscription} = Brama.subscribe(events: [:state_change])
  iex> Brama.unsubscribe(subscription)
  :ok
  ```
  """
  def unsubscribe(subscription_id) do
    EventDispatcher.unsubscribe(subscription_id)
  end
end
