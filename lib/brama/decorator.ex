defmodule Brama.Decorator do
  @moduledoc """
  Provides macros for decorating functions with circuit breaker functionality.

  ## Usage

  ```elixir
  defmodule PaymentService do
    use Brama.Decorator

    @circuit_breaker identifier: "payment_api"
    def process_payment(payment) do
      # This function will be wrapped with circuit breaker logic
      PaymentAPI.process(payment)
    end

    @circuit_breaker identifier: "refund_api",
                    error_handler: fn
                      {:ok, _} -> :success
                      {:error, _} -> :failure
                    end
    def process_refund(refund) do
      # Custom error handler
      RefundAPI.process(refund)
    end

    def fallback_function(_args) do
      {:error, :service_unavailable}
    end

    @circuit_breaker identifier: "invoice_api",
                    fallback: &fallback_function/1
    def generate_invoice(data) do
      # Will use fallback when circuit is open
      InvoiceAPI.generate(data)
    end
  end
  """
  require Logger

  defmacro __using__(_opts) do
    quote do
      import Brama.Decorator, only: [circuit_breaker: 1]
      Module.register_attribute(__MODULE__, :circuit_breaker_functions, accumulate: true)
      @before_compile Brama.Decorator
    end
  end

  defmacro __before_compile__(env) do
    circuit_breaker_functions = Module.get_attribute(env.module, :circuit_breaker_functions) || []

    functions =
      for {function, arity, identifier, opts} <- circuit_breaker_functions do
        args = Macro.generate_arguments(arity, env.module)

        quote do
          defoverridable [{unquote(function), unquote(arity)}]

          def unquote(function)(unquote_splicing(args)) do
            Brama.Decorator.decorate(
              unquote(identifier),
              fn -> super(unquote_splicing(args)) end,
              [unquote_splicing(args)],
              unquote(opts)
            )
          end
        end
      end

    quote do
      (unquote_splicing(functions))
    end
  end

  @doc false
  defmacro circuit_breaker(opts) do
    quote bind_quoted: [opts: opts] do
      {function, arity} = __ENV__.function
      identifier = Keyword.fetch!(opts, :identifier)
      remaining_opts = Keyword.delete(opts, :identifier)

      # Register the function for decoration
      @circuit_breaker_functions {function, arity, identifier, remaining_opts}

      # Ensure the connection is registered at runtime
      Brama.register(identifier)
    end
  end

  @doc false
  def decorate(identifier, function, args, opts) do
    # Ensure the connection is registered at runtime
    ensure_registered(identifier)

    if Brama.available?(identifier) do
      execute_with_circuit_breaker(identifier, function, opts)
    else
      handle_open_circuit(identifier, args, opts)
    end
  end

  # Ensure the connection is registered
  defp ensure_registered(identifier) do
    case Brama.register(identifier) do
      {:ok, _} -> :ok
      {:error, :already_registered} -> :ok
    end
  end

  # Execute the function with circuit breaker protection
  defp execute_with_circuit_breaker(identifier, function, opts) do
    try do
      # Call the original function
      result = function.()
      handle_result(identifier, result, opts)
    rescue
      exception ->
        # Report failure on exception
        Brama.failure(identifier, reason: Exception.message(exception))
        reraise exception, __STACKTRACE__
    end
  end

  # Handle the result of the function call
  defp handle_result(identifier, result, opts) do
    case process_result(result, opts) do
      :success ->
        Brama.success(identifier)
        result

      :ignore ->
        result

      {:failure, reason} ->
        Brama.failure(identifier, reason: reason)
        result
    end
  end

  # Handle the case when the circuit is open
  defp handle_open_circuit(identifier, args, opts) do
    # Circuit is open, use fallback if provided
    case Keyword.get(opts, :fallback) do
      nil ->
        {:error, :circuit_open}

      fallback when is_function(fallback) ->
        # Log that we're using the fallback
        Logger.debug("Circuit #{identifier} is open, using fallback function")
        # Apply the fallback function with the arguments
        apply(fallback, args)
    end
  end

  # Default result processor
  defp process_result(result, opts) do
    case Keyword.get(opts, :error_handler) do
      nil -> default_error_handler(result)
      handler when is_function(handler) -> handler.(result)
    end
  end

  # Default error handler logic
  defp default_error_handler(result) do
    case result do
      {:ok, _} -> :success
      {:error, reason} -> {:failure, reason}
      _ -> :ignore
    end
  end
end
