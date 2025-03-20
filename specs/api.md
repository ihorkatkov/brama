# API Specification

## Overview

This document specifies the public API for the Brama library. It details the functions available to client applications, their parameters, return values, and usage examples.

## Core API Functions

### Connection Management

#### Registration

```elixir
@spec register(identifier :: String.t(), opts :: Keyword.t()) :: {:ok, term()} | {:error, term()}
def register(identifier, opts \\ [])
```

Registers a new connection with Brama.

**Parameters:**
- `identifier` - String identifier for the connection
- `opts` - Options including:
  - `type` - Connection type (default: `:general`)
  - `scope` - Grouping category (default: `nil`)
  - `max_attempts` - Override default threshold (default: from config)
  - `expiry` - Override default expiry time (default: from config)
  - `expiry_strategy` - Strategy for circuit expiry (`:fixed` or `:progressive`)
  - `initial_expiry` - Initial expiry time for progressive strategy (in ms)
  - `max_expiry` - Maximum expiry time for progressive strategy (in ms)
  - `backoff_factor` - Multiplier for progressive backoff (e.g., 2.0)
  - `metadata` - Additional information (default: `%{}`)

**Expiry Strategies:**
- `:fixed` - Always uses the same expiry time (default)
- `:progressive` - Increases expiry time after each failure using formula: `min(max_expiry, initial_expiry * (backoff_factor ^ failure_count))`

**Returns:**
- `{:ok, connection_data}` - Successfully registered
- `{:error, reason}` - Registration failed

**Example:**
```elixir
# Basic registration
Brama.register("payment_api", 
  type: :http, 
  scope: "payment_services",
  max_attempts: 5,
  expiry: 30_000
)

# Registration with progressive backoff
Brama.register("flaky_service",
  scope: "external_apis",
  expiry_strategy: :progressive,
  initial_expiry: 5_000,
  max_expiry: 120_000,
  backoff_factor: 2.0
)
```

#### Unregistration

```elixir
@spec unregister(identifier :: String.t(), opts :: Keyword.t()) :: :ok | {:error, term()}
def unregister(identifier, opts \\ [])
```

Removes a connection from Brama.

**Parameters:**
- `identifier` - String identifier for the connection
- `opts` - Options including:
  - `type` - Connection type (default: `:general`)
  - `scope` - Grouping category (default: `nil`)

**Returns:**
- `:ok` - Successfully unregistered
- `{:error, :not_found}` - Connection not found

**Example:**
```elixir
Brama.unregister("payment_api")
```

### Status Checking

```elixir
@spec available?(identifier :: String.t(), opts :: Keyword.t()) :: boolean()
def available?(identifier, opts \\ [])
```

Checks if a connection is available (circuit closed).

**Parameters:**
- `identifier` - String identifier for the connection
- `opts` - Options including:
  - `type` - Connection type (default: `:general`)
  - `scope` - Grouping category (default: `nil`)

**Returns:**
- `true` - Connection is available
- `false` - Connection is unavailable or not found

**Example:**
```elixir
if Brama.available?("payment_api") do
  # Make API call
else
  # Use fallback
end
```

### Status Reporting

```elixir
@spec success(identifier :: String.t(), opts :: Keyword.t()) :: :ok | {:error, term()}
def success(identifier, opts \\ [])

@spec failure(identifier :: String.t(), opts :: Keyword.t()) :: :ok | {:error, term()}
def failure(identifier, opts \\ [])
```

Report connection success or failure.

**Parameters:**
- `identifier` - String identifier for the connection
- `opts` - Options including:
  - `type` - Connection type (default: `:general`)
  - `scope` - Grouping category (default: `nil`)
  - `reason` - Optional reason for failure (for `failure/2` only)

**Returns:**
- `:ok` - Status updated
- `{:error, :not_found}` - Connection not found

**Example:**
```elixir
case make_api_call() do
  {:ok, result} -> 
    Brama.success("payment_api")
    {:ok, result}
  {:error, reason} -> 
    Brama.failure("payment_api", reason: inspect(reason))
    {:error, reason}
end
```

### Status Retrieval

```elixir
@spec status(identifier :: String.t(), opts :: Keyword.t()) :: {:ok, map()} | {:error, term()}
def status(identifier, opts \\ [])
```

Get detailed status for a connection.

**Parameters:**
- `identifier` - String identifier for the connection
- `opts` - Options including:
  - `type` - Connection type (default: `:general`)
  - `scope` - Grouping category (default: `nil`)

**Returns:**
- `{:ok, status_map}` - Status information
- `{:error, :not_found}` - Connection not found

**Example:**
```elixir
{:ok, status} = Brama.status("payment_api")
IO.puts("Connection state: #{status.state}, Failures: #{status.failure_count}")
```

## Circuit Control API

### Manual Circuit Control

```elixir
@spec open_circuit!(identifier :: String.t(), opts :: Keyword.t()) :: :ok | {:error, term()}
def open_circuit!(identifier, opts \\ [])

@spec close_circuit!(identifier :: String.t(), opts :: Keyword.t()) :: :ok | {:error, term()}
def close_circuit!(identifier, opts \\ [])

@spec reset_circuit!(identifier :: String.t(), opts :: Keyword.t()) :: :ok | {:error, term()}
def reset_circuit!(identifier, opts \\ [])
```

Manually control circuit state.

**Parameters:**
- `identifier` - String identifier for the connection
- `opts` - Options including:
  - `type` - Connection type (default: `:general`)
  - `scope` - Grouping category (default: `nil`)
  - `reason` - Optional reason for state change
  - `expires_in` - Optional custom expiry (for `open_circuit!/2` only)

**Returns:**
- `:ok` - Circuit state updated
- `{:error, reason}` - Operation failed

**Example:**
```elixir
# Force open for maintenance
Brama.open_circuit!("payment_api", 
  reason: "Scheduled maintenance", 
  expires_in: 3_600_000
)

# Force close after maintenance
Brama.close_circuit!("payment_api")
```

## Event System API

### Subscription Management

```elixir
@spec subscribe(opts :: Keyword.t()) :: {:ok, reference()} | {:error, term()}
def subscribe(opts \\ [])

@spec unsubscribe(opts :: Keyword.t()) :: :ok | {:error, term()}
def unsubscribe(opts \\ [])
```

Subscribe/unsubscribe to connection events.

**Parameters:**
- `opts` - Filter options including:
  - `events` - List of event types (default: all)
  - `connection` - Connection identifier (default: all)
  - `scope` - Connection scope (default: all)
  - `handler` - Custom handler module (default: send messages to current process)

**Returns:**
- `{:ok, subscription_reference}` - Subscription successful
- `{:error, reason}` - Subscription failed

**Example:**
```elixir
# Subscribe to all state changes
{:ok, _ref} = Brama.subscribe(events: [:state_change])

# Handle events
def handle_info({:brama_event, event}, state) do
  Logger.info("Connection #{event.connection} changed to #{event.data.new_state}")
  {:noreply, state}
end
```
## Configuration API

```elixir
@spec configure(config :: Keyword.t() | String.t(), opts :: Keyword.t()) :: :ok | {:error, term()}
def configure(config, opts \\ [])
```

Update configuration at runtime.

**Parameters:**
- `config` - Configuration keywords or connection identifier
- `opts` - Configuration options when first parameter is a connection

**Returns:**
- `:ok` - Configuration updated
- `{:error, reason}` - Update failed

**Example:**
```elixir
# Update global settings
Brama.configure(max_attempts: 10, expiry: 60_000)

# Update specific connection
Brama.configure("payment_api",
  max_attempts: 5,
  expiry: 30_000,
  expiry_strategy: :progressive,
  initial_expiry: 5_000,
  max_expiry: 60_000,
  backoff_factor: 2.0
)
```

### Expiry Strategies

Brama supports different strategies for determining how long a circuit remains open:

#### Fixed Expiry (Default)

The circuit remains open for a fixed amount of time before transitioning to half-open:

```elixir
Brama.configure("payment_api",
  expiry_strategy: :fixed,  # This is the default strategy
  expiry: 30_000            # 30 seconds
)
```

#### Progressive Backoff

The circuit's expiry time increases with each consecutive failure, allowing for more sophisticated self-healing:

```elixir
Brama.configure("flaky_service",
  expiry_strategy: :progressive,
  initial_expiry: 5_000,     # Start with 5 seconds
  max_expiry: 300_000,       # Cap at 5 minutes
  backoff_factor: 2.0        # Double the time with each failure
)
```

With this configuration, expiry times would progress: 5s → 10s → 20s → 40s → 80s → 160s → 300s (capped at max)

## Decorator API

The decorator API uses the [Decorator](https://hexdocs.pm/decorator/) library to provide a clean way to wrap functions with circuit breaking logic.

### Usage

```elixir
defmodule PaymentService do
  use Brama.Decorator

  @decorate circuit_breaker(identifier: "payment_api")
  def process_payment(payment) do
    PaymentAPI.process(payment)
  end
end
```

### Decorator Options

The circuit breaker decorator accepts the following options:

- `identifier` - A unique string identifier for the circuit breaker instance (required)
- `error_handler` - Custom function to handle responses and determine success/failure status (optional)

### Error Handling

The error handler function can return the following statuses:

- `:success` - Operation completed successfully, keeps circuit closed
- `:failure` - Operation failed, increments failure count
- `{:failure, reason}` - Operation failed with specific reason
- `:ignore` - Operation result should not affect circuit breaker state

Default error handling behavior:

```elixir
@decorate circuit_breaker(
  identifier: "payment_api",
  error_handler: fn
    {:ok, _} -> :success
    {:error, reason} -> {:failure, reason}
    _ -> :ignore
  end
)
def process_payment(payment) do
  PaymentAPI.process(payment)
end
```

### Service Unavailability

When the circuit is open:
1. The decorated function is not executed
2. Returns `{:error, status}` where status contains circuit breaker state
3. Prevents overwhelming failing services with requests

Example response when circuit is open:
```elixir
{:error, status} # where status contains circuit breaker state information
```

### Exception Handling

When an exception occurs in the decorated function:
1. The exception is logged for debugging
2. A failure is recorded with the exception message as reason
3. The original exception is re-raised with preserved stacktrace

```elixir
@decorate Brama.Decorator.circuit_breaker(opts)
def my_function(args) do
  # Function body
end
```

Wraps functions with circuit breaker functionality.

**Parameters:**
- `opts` - Options including:
  - `identifier` - Connection identifier (required)
  - `error_handler` - Custom function to handle errors and determine success/failure (optional)

**Error Handling:**
The error handler can return:
- `:success` - Operation completed successfully
- `:failure` - Operation failed
- `{:failure, reason}` - Operation failed with specific reason
- `:ignore` - Operation result should not affect circuit state

**Example:**
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