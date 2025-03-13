defmodule Brama.TestHelpers do
  @moduledoc """
  Provides helper functions for testing applications that use Brama.

  This module is intended to be used in test environments to:
  - Control time for deterministic testing
  - Manipulate circuit states directly
  - Assert on events and state transitions
  - Simulate failures and recovery

  ## Usage

  ```elixir
  # In your test file
  use ExUnit.Case
  import Brama.TestHelpers

  test "circuit opens after failures" do
    # Setup
    Brama.register("test_api")

    # Simulate failures
    add_failures("test_api", 10)

    # Assert circuit state
    assert_circuit_open("test_api")
  end
  """

  import ExUnit.Assertions

  @doc """
  Advances the simulated time by the specified number of milliseconds.

  Only works when testing_mode is enabled in config.

  ## Examples

      iex> advance_time(60_000) # Advance 1 minute
      :ok
  """
  @spec advance_time(integer()) :: :ok
  def advance_time(milliseconds) when is_integer(milliseconds) and milliseconds > 0 do
    # This is a placeholder for the actual implementation
    # In a real implementation, this would modify a shared time reference
    # that the ConnectionManager would use instead of System.monotonic_time
    :ok
  end

  @doc """
  Sets the absolute simulated time.

  Only works when testing_mode is enabled in config.

  ## Examples

      iex> set_time(1630000000000)
      :ok
  """
  @spec set_time(integer()) :: :ok
  def set_time(timestamp) when is_integer(timestamp) and timestamp > 0 do
    # This is a placeholder for the actual implementation
    :ok
  end

  @doc """
  Directly sets the state of a circuit.

  ## Examples

      iex> set_state("payment_api", :open)
      :ok
  """
  @spec set_state(String.t(), atom(), Keyword.t()) :: :ok | {:error, term()}
  def set_state(identifier, state, opts \\ [])
      when is_binary(identifier) and state in [:closed, :open, :half_open] do
    case Brama.status(identifier, opts) do
      {:ok, _data} ->
        # Use the appropriate function based on the desired state
        case state do
          :open ->
            Brama.open_circuit!(identifier, Keyword.put(opts, :reason, "Test setup"))

          :closed ->
            Brama.close_circuit!(identifier, Keyword.put(opts, :reason, "Test setup"))

          :half_open ->
            # First open the circuit
            Brama.open_circuit!(identifier, Keyword.put(opts, :reason, "Test setup"))
            # Set state to half-open
            set_half_open_state(identifier, opts)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helper to set a circuit to half-open state
  @spec set_half_open_state(String.t(), Keyword.t()) :: :ok
  defp set_half_open_state(identifier, opts) do
    :sys.replace_state(Brama.ConnectionManager, fn state ->
      key = connection_key(identifier, opts)
      update_connection_state(state, key)
    end)

    # Return :ok to match the expected return value
    :ok
  end

  # Helper to create a connection key from identifier and scope
  @spec connection_key(String.t(), Keyword.t()) :: String.t()
  defp connection_key(identifier, opts) do
    scope = Keyword.get(opts, :scope)
    if scope, do: "#{scope}:#{identifier}", else: identifier
  end

  # Helper to update connection state to half-open
  @spec update_connection_state(map(), String.t()) :: map()
  defp update_connection_state(state, key) do
    if connection = state.connections[key] do
      # Set the state to half-open
      updated_connection = %{connection | state: :half_open}
      put_in(state.connections[key], updated_connection)
    else
      state
    end
  end

  @doc """
  Adds a specific number of failures to a connection.

  ## Examples

      iex> add_failures("payment_api", 5)
      :ok
  """
  @spec add_failures(String.t(), non_neg_integer(), Keyword.t()) :: :ok | {:error, term()}
  def add_failures(identifier, count, opts \\ [])
      when is_binary(identifier) and is_integer(count) and count >= 0 do
    # Add failures one by one
    Enum.reduce_while(1..count, :ok, fn _, _acc ->
      case Brama.failure(identifier, Keyword.put(opts, :reason, "Test failure")) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  @doc """
  Asserts that a circuit is in the open state.

  ## Examples

      iex> assert_circuit_open("payment_api")
      :ok
  """
  @spec assert_circuit_open(String.t(), Keyword.t()) :: :ok
  def assert_circuit_open(identifier, opts \\ []) when is_binary(identifier) do
    case Brama.status(identifier, opts) do
      {:ok, %{state: :open}} ->
        :ok

      {:ok, %{state: actual_state}} ->
        flunk("Expected circuit '#{identifier}' to be open, but was #{actual_state}")

      {:error, reason} ->
        flunk("Error checking circuit state: #{inspect(reason)}")
    end
  end

  @doc """
  Asserts that a circuit is in the closed state.

  ## Examples

      iex> assert_circuit_closed("payment_api")
      :ok
  """
  @spec assert_circuit_closed(String.t(), Keyword.t()) :: :ok
  def assert_circuit_closed(identifier, opts \\ []) when is_binary(identifier) do
    case Brama.status(identifier, opts) do
      {:ok, %{state: :closed}} ->
        :ok

      {:ok, %{state: actual_state}} ->
        flunk("Expected circuit '#{identifier}' to be closed, but was #{actual_state}")

      {:error, reason} ->
        flunk("Error checking circuit state: #{inspect(reason)}")
    end
  end

  @doc """
  Asserts that a circuit is in the half-open state.

  ## Examples

      iex> assert_circuit_half_open("payment_api")
      :ok
  """
  @spec assert_circuit_half_open(String.t(), Keyword.t()) :: :ok
  def assert_circuit_half_open(identifier, opts \\ []) when is_binary(identifier) do
    case Brama.status(identifier, opts) do
      {:ok, %{state: :half_open}} ->
        :ok

      {:ok, %{state: actual_state}} ->
        flunk("Expected circuit '#{identifier}' to be half-open, but was #{actual_state}")

      {:error, reason} ->
        flunk("Error checking circuit state: #{inspect(reason)}")
    end
  end

  @doc """
  Waits for a specific event to be received.

  ## Examples

      iex> wait_for_event(:state_change, connection: "payment_api")
      {:ok, event}
  """
  @spec wait_for_event(atom(), Keyword.t()) :: {:ok, map()} | {:error, :timeout}
  def wait_for_event(event_type, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 1000)

    # Try to subscribe to events
    subscribe_result =
      try do
        Brama.subscribe(events: [event_type] ++ Keyword.take(opts, [:connection, :scope]))
      rescue
        _ -> {:error, :subscription_failed}
      end

    # Process the result based on subscription success
    case subscribe_result do
      {:ok, subscription} ->
        # Set up a receive block with timeout
        result =
          receive do
            {:brama_event, event} ->
              {:ok, event}
          after
            timeout ->
              {:error, :timeout}
          end

        # Clean up subscription
        try do
          Brama.unsubscribe(subscription)
        rescue
          _ -> :ok
        end

        result

      _ ->
        # Return a timeout error if we can't subscribe
        {:error, :timeout}
    end
  end

  @doc """
  Asserts that a specific event was received.

  ## Examples

      iex> assert_event_received(:state_change, connection: "payment_api")
      :ok
  """
  @spec assert_event_received(atom(), Keyword.t()) :: :ok
  def assert_event_received(event_type, opts \\ []) do
    result = wait_for_event(event_type, opts)

    if match?({:ok, _}, result) do
      :ok
    else
      connection = Keyword.get(opts, :connection, "any")
      flunk("Expected #{event_type} event for #{connection} but none received")
    end
  end

  @doc """
  Simulates a service temporarily failing.

  ## Examples

      iex> simulate_failures("payment_api", 5)
      :ok
  """
  @spec simulate_failures(String.t(), non_neg_integer(), Keyword.t()) :: :ok | {:error, term()}
  def simulate_failures(identifier, count, opts \\ []) do
    add_failures(identifier, count, opts)
  end

  @doc """
  Simulates a service recovering.

  ## Examples

      iex> simulate_recovery("payment_api")
      :ok
  """
  @spec simulate_recovery(String.t(), Keyword.t()) :: :ok | {:error, term()}
  def simulate_recovery(identifier, opts \\ []) do
    Brama.success(identifier, opts)
  end
end
