# Circuit Breaking Specification

## Overview

Circuit breaking is a key resilience pattern in Brama that prevents cascading failures by stopping requests to failing dependencies. This document outlines how the circuit breaker works, state transitions, and configuration options.

## Circuit States

The circuit breaker pattern involves three distinct states:

1. **Closed** (`:closed`)
   - Normal operation
   - All requests to the dependency are allowed
   - Failures are counted
   - Transitions to open when failure threshold is reached

2. **Open** (`:open`)
   - Failure state
   - All requests are immediately rejected without attempting to call the dependency
   - Failure fast prevents resource exhaustion
   - Transitions to half-open after expiry time passes

3. **Half-Open** (`:half_open`)
   - Recovery testing state
   - A limited number of test requests are allowed
   - Success transitions to closed
   - Failure transitions back to open

## State Transition Rules

### Closed to Open
- Transition occurs when consecutive failures reach `max_attempts` threshold
- Default `max_attempts` is 10 (configurable)
- When transitioning to open, a timestamp is recorded for expiry calculation

### Open to Half-Open
- Transition occurs automatically after `expiry` time has passed
- Default `expiry` is 60,000ms (1 minute, configurable)
- No requests allowed during open state

### Half-Open to Closed
- First successful request in half-open state transitions to closed
- Resets failure counter to 0

### Half-Open to Open
- First failed request in half-open state transitions back to open
- Resets expiry timer

## Configuration

The circuit breaker can be configured globally:

```elixir
config :brama,
  max_attempts: 10,         # Attempts before circuit opens
  expiry: 60_000            # Circuit open duration in ms
```

Or per-connection during registration:

```elixir
Brama.register("payment_api", max_attempts: 5, expiry: 30_000)
```

## Implementation Details

### Failure Counting

- Only consecutive failures count toward threshold
- A single success resets the consecutive failure counter to 0
- Different connection types track failures separately

### Fast Circuit Check

- Circuit status checks are designed to be very fast (constant time)
- No network or disk I/O during status checks
- Optimized for high-throughput applications

### Thread Safety

- All circuit state operations are atomic
- Concurrent requests will see consistent circuit state

## Manual Circuit Control

In addition to automatic circuit breaking, Brama provides manual control:

```elixir
# Force open a circuit
Brama.open_circuit!(identifier, reason: "Maintenance", expires_in: 3_600_000)

# Force close a circuit
Brama.close_circuit!(identifier)

# Reset circuit to initial state
Brama.reset_circuit!(identifier)
```

## Testing Mode

For testing, a special mode is available:

```elixir
# In test environments
config :brama, testing_mode: true
```

In testing mode:
- Circuits can be manually controlled
- Automatic transitions can be triggered
- Time-based transitions can be simulated 