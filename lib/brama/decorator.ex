defmodule Brama.Decorator do
  @moduledoc """
  Provides macros for decorating functions with circuit breaker functionality to improve system resilience
  and handle failures gracefully.

  ## Overview

  The circuit breaker pattern helps prevent cascading failures by monitoring service calls and
  automatically stopping requests when a service is experiencing issues. It operates in three states:
  - Closed (normal operation)
  - Open (service calls blocked)
  - Half-open (testing if service recovered)

  ## Configuration

  The decorator accepts the following options:
  * `identifier` - (required) A unique string identifier for the circuit breaker instance
  * `error_handler` - (optional) A function to handle responses and determine success/failure status

  ## Error Handling

  The error handler function can return the following statuses:
  * `:success` - Operation completed successfully, keeps circuit closed
  * `:failure` - Operation failed, increments failure count
  * `{:failure, reason}` - Operation failed with specific reason
  * `:ignore` - Operation result should not affect circuit breaker state

  Default error handler behavior:
  ```elixir
  def default_error_handler(result) do
    case result do
      {:ok, _} -> :success
      {:error, reason} -> {:failure, reason}
      _ -> :ignore
    end
  end
  ```

  ## Exception Handling

  When an exception occurs:
  1. The exception is logged for debugging
  2. A failure is recorded with the exception message as reason
  3. The original exception is re-raised with preserved stacktrace

  ## Service Unavailability

  When the circuit is open:
  1. The decorated function is not executed
  2. Returns `{:error, status}` where status contains circuit breaker state
  3. Prevents overwhelming failing services with requests

  ## Examples

  Basic usage with default error handling:
  ```elixir
  defmodule PaymentService do
    use Brama.Decorator

    @decorate circuit_breaker(identifier: "payment_api")
    def process_payment(payment) do
      PaymentAPI.process(payment)
    end
  end
  ```

  Custom error handling:
  ```elixir
  defmodule PaymentService do
    use Brama.Decorator

    @decorate circuit_breaker(
      identifier: "refund_api",
      error_handler: fn
        {:ok, _} -> :success
        {:error, :invalid_amount} -> {:failure, :validation_error}
        {:error, :network_timeout} -> {:failure, :service_unavailable}
        _ -> :ignore
      end
    )
    def process_refund(refund) do
      RefundAPI.process(refund)
    end
  end
  ```

  ## Return Values

  The decorated function preserves the original return value when the circuit is closed.
  When the circuit is open, it returns:
  ```elixir
  {:error, status} # where status contains circuit breaker state information
  ```
  """

  require Logger
  use Decorator.Define, circuit_breaker: 1

  @doc """
  Decorator function that wraps a function with circuit breaker functionality.

  ## Options

  - `identifier` - Connection identifier (required)
  - `error_handler` - Custom function to handle errors and determine success/failure

  ## Examples

  ```elixir
  @decorate circuit_breaker(identifier: "payment_api")
  def process_payment(payment) do
    # This function will be wrapped with circuit breaker logic
    PaymentAPI.process(payment)
  end
  ```
  """
  def circuit_breaker(opts, body, _context) do
    quote do
      identifier = Keyword.fetch!(unquote(opts), :identifier)

      error_handler =
        Keyword.get(unquote(opts), :error_handler, &Brama.Decorator.default_error_handler/1)

      Brama.Decorator.ensure_registered(identifier)

      if Brama.available?(identifier) do
        try do
          result = unquote(body)

          case error_handler.(result) do
            :success ->
              Brama.success(identifier)
              result

            :ignore ->
              result

            :failure ->
              Brama.failure(identifier, reason: :error)
              result

            {:failure, reason} ->
              Brama.failure(identifier, reason: reason)
              result
          end
        rescue
          exception ->
            dbg(exception)
            Brama.failure(identifier, reason: Exception.message(exception))
            reraise exception, __STACKTRACE__
        end
      else
        {:ok, status} = Brama.status(identifier)

        {:error, status}
      end
    end
  end

  def default_error_handler(result) do
    case result do
      {:ok, _} -> :success
      {:error, reason} -> {:failure, reason}
      _ -> :ignore
    end
  end

  def ensure_registered(identifier) do
    Brama.register(identifier)
    |> case do
      {:ok, _} -> :ok
      {:error, :already_registered} -> :ok
    end
  end
end
