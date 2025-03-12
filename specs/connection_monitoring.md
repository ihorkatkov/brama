# Connection Monitoring Specification

## Overview

Connection monitoring is a core feature of Brama that tracks the status of connections to external dependencies. This document outlines how connection monitoring works, its data structures, and key functions.

## Connection Identification

Each connection is uniquely identified by:
- A string identifier (required) - Typically representing the service name
- A scope (optional) - For grouping related connections (e.g., "payments", "inventory")

This combination allows for precise tracking and management of multiple connections to the same service.

## Connection States

Connections can be in one of the following states:

| State | Description |
|-------|-------------|
| `:closed` | Default state, connection is operational |
| `:open` | Circuit is open, connection is not accepting requests |
| `:half_open` | Transitional state to test if the connection has recovered |
| `:unknown` | Initial state before any data has been collected |

## Data Structure

Each connection will be stored with the following information:

```elixir
%{
  identifier: "service_name",
  scope: "system",             # Optional, default is nil
  state: :closed,              # Current circuit state
  failure_count: 0,            # Number of consecutive failures
  last_failure_time: nil,      # Timestamp of last failure
  last_success_time: nil,      # Timestamp of last success
  opened_at: nil,              # When the circuit was last opened
  metadata: %{}                # Optional user-defined metadata
}
```

## Core Functions

### Registration

```elixir
Brama.register(identifier, opts \\ [])
```

Registers a new connection with the system. Options include:
- `scope`: Grouping category (default: `nil`)
- `metadata`: Custom information about the connection

### Status Checking

```elixir
Brama.available?(identifier, opts \\ [])
```

Checks if a connection is available (circuit closed). Returns:
- `true` - Connection is available
- `false` - Connection is unavailable (circuit open)

### Status Reporting

```elixir
Brama.success(identifier, opts \\ [])
Brama.failure(identifier, opts \\ [])
```

These functions report connection success or failure, updating internal counters and potentially changing the circuit state.

### Status Retrieval

```elixir
Brama.status(identifier, opts \\ [])
```

Returns detailed status information about a connection:
```elixir
{:ok, %{state: :closed, failure_count: 0, ...}}
```

## Connection Lifecycle

1. Connection is registered with `Brama.register/2`
2. Application checks availability with `Brama.available?/2` before making external calls
3. Application reports success or failure with `Brama.success/2` or `Brama.failure/2`
4. If failure threshold is reached, circuit opens
5. After expiry time, circuit transitions to half-open
6. First successful call in half-open state closes the circuit

## Monitoring Metrics

The following metrics will be available for each connection:
- Current state
- Total failure count
- Consecutive failure count
- Time since last state change
- Success rate (ratio of successful to total calls)

## Connection Cleanup

Inactive connections can be removed using:
```elixir
Brama.unregister(identifier, opts \\ [])
```

Additionally, the system will periodically clean up connections that have been inactive for a configurable period. 