defmodule Brama.TestHelpers do
  @moduledoc """
  Provides helper functions for testing applications that use Brama.

  This module is intended to be used in test environments to:
  - Manipulate circuit states directly
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
    assert {:ok, %{state: :open}} = Brama.status("test_api")
  end
  """

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
