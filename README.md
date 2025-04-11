# Brama

Brama is an Elixir library for reliable connection management with external dependencies. It provides robust tracking of connection statuses to APIs, services, databases, or any external system, with built-in circuit breaking to prevent cascading failures.

## Overview

When your application depends on external systems, knowing their availability status becomes critical. Brama serves as a gatekeeper (the name "Brama" means "gate" in several languages), monitoring your connections and protecting your application from external system failures.

## Features

- **Connection Monitoring**: Track status of any connection
- **Circuit Breaking**: Automatically prevent requests to failing systems after a threshold is reached
- **Self-Healing**: Connections automatically reset after a configurable expiry time
- **Status Notifications**: Subscribe to connection status change events
- **Failure Isolation**: Protect your application from cascading failures
- **Minimal Configuration**: Simple setup with reasonable defaults
- **Decorator API**: Simple function decorators for automatic circuit breaking
- **Flexible Expiry Strategies**: Fixed or progressive backoff strategies

## Installation

Add Brama to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:brama, "~> 1.0.2"},
  ]
end
```

## Circuit Breaking Mechanism

Brama implements circuit breaking for any connection with these behaviors:

1. Each connection type is tracked separately
2. After a configurable number of failed attempts (default: 10), the circuit opens
3. When open, all requests are rejected without attempting the external call
4. After a configurable time period (default: 1 minute), the circuit transitions to half-open
5. Connections have immediate status updates

## Configuration Options

```elixir
config :brama,
  max_attempts: 10,           # Attempts before circuit opens
  cleanup_interval: 10_000,   # Status check interval in ms
  expiry: 60_000              # Circuit open duration in ms
```

## Basic Usage

```elixir
# Register a connection
Brama.register("payment_api", type: :http, scope: "payment_services")

# Before making an external call
if Brama.available?("payment_api") do
  case make_api_call() do
    {:ok, result} -> 
      Brama.success("payment_api")
      {:ok, result}
    {:error, reason} -> 
      Brama.failure("payment_api")
      {:error, reason}
  end
else
  # Use fallback or return error
  {:error, :service_unavailable}
end
```

## Decorator API

For a cleaner integration, use the decorator API:

```elixir
defmodule PaymentService do
  use Brama.Decorator

  @decorate circuit_breaker(identifier: "payment_api")
  def process_payment(payment) do
    PaymentAPI.process(payment)
  end
  
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

## Expiry Strategies

Brama supports different strategies for determining how long a circuit remains open:

### Fixed Expiry (Default)

```elixir
Brama.configure("payment_api",
  expiry_strategy: :fixed,  # This is the default strategy
  expiry: 30_000            # 30 seconds
)
```

### Progressive Backoff

```elixir
Brama.configure("flaky_service",
  expiry_strategy: :progressive,
  initial_expiry: 5_000,     # Start with 5 seconds
  max_expiry: 300_000,       # Cap at 5 minutes
  backoff_factor: 2.0        # Double the time with each failure
)
```

With progressive backoff, expiry times would increase with each failure: 5s → 10s → 20s → 40s → etc.

## Event Notifications

Subscribe to connection status changes:

```elixir
# Subscribe to all state changes
Brama.subscribe(events: [:state_change])

# Handle events in a GenServer
def handle_info({:brama_event, event}, state) do
  Logger.info("Connection #{event.connection} changed to #{event.data.new_state}")
  {:noreply, state}
end
```

## Advanced Usage

You can extend Brama for specific needs:

- Create custom monitoring modules for specialized protocols
- Implement advanced health checking logic
- Build metrics collection around connection statuses
- Integrate with monitoring and alerting systems

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

Brama is released under the MIT License.
