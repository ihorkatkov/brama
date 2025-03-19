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
  - `metadata` - Additional information (default: `%{}`)

**Returns:**
- `{:ok, connection_data}` - Successfully registered
- `{:error, reason}` - Registration failed

**Example:**
```elixir
Brama.register("payment_api", 
  type: :http, 
  scope: "payment_services",
  max_attempts: 5,
  expiry: 30_000
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
Brama.configure(max_attempts: 15, expiry: 120_000)

# Update connection-specific settings
Brama.configure("payment_api", max_attempts: 5, expiry: 30_000)
```

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