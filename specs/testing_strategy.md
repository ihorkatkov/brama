# Testing Strategy Specification

## Overview

This document outlines the simplified MVP testing strategy for the Brama library. It focuses on essential unit testing and integration testing.

## Testing Levels

### Unit Testing

All components of Brama will have comprehensive unit tests:

Each unit test will focus on a single component in isolation, using mocks or stubs for dependencies.

### Integration Testing

Integration tests will verify interactions between components:

- Connection registration to event notification flow
- Circuit state transitions under various conditions
- Cleanup and expiry interactions

## Testing Features

### Testing Mode

Brama includes a testing mode to facilitate easier testing:

```elixir
# In config/test.exs
config :brama, testing_mode: true
```

Testing mode provides:
- Deterministic timestamps (controlled by test code)
- Manual state transition triggers
- Synchronous event delivery
- Detailed logging of internal state changes

### Time Control

Tests can control the passage of time in testing mode:

```elixir
# Advance time by 1 minute
Brama.TestHelpers.advance_time(60_000)

# Set absolute time
Brama.TestHelpers.set_time(1630000000000)
```

### State Manipulation

Tests can directly manipulate circuit state:

```elixir
# Force a connection into specific state
Brama.TestHelpers.set_state("payment_api", :open)

# Add failure count
Brama.TestHelpers.add_failures("payment_api", 5)
```

### Event Testing

Tools for testing event subscriptions:

```elixir
# Assert event was received
Brama.TestHelpers.assert_event_received(:state_change, 
  connection: "payment_api",
  previous_state: :closed,
  new_state: :open
)

# Wait for specific event
Brama.TestHelpers.wait_for_event(:state_change, timeout: 1000)
```

## Test Helpers

Brama provides test helpers to make testing applications easier:

### Mocking External Services

Helpers for simulating dependency failures:

```elixir
# Simulate a service temporarily failing
Brama.TestHelpers.simulate_failures("payment_api", 5)

# Simulate service recovery
Brama.TestHelpers.simulate_recovery("payment_api")
```

### Assertion Helpers

Specialized assertions for circuit breaker behavior:

```elixir
# Assert circuit is open
Brama.TestHelpers.assert_circuit_open("payment_api")

# Assert circuit opened after exactly N failures
Brama.TestHelpers.assert_circuit_opens_after("payment_api", 10)

# Assert circuit closes after expiry and success
Brama.TestHelpers.assert_circuit_closes_after_expiry("payment_api")
```

## Testing Strategies for Applications

### Unit Testing with Brama

For applications using Brama, use these testing strategies:

```elixir
# Example test with Brama
defmodule MyApp.PaymentServiceTest do
  use ExUnit.Case
  import Brama.TestHelpers

  setup do
    # Register test connection
    Brama.register("payment_api")
    :ok
  end

  test "handles payment service unavailability gracefully" do
    # Force circuit open
    set_state("payment_api", :open)
    
    # Call code that should handle unavailability
    result = MyApp.PaymentService.process_payment(100)
    
    # Assert correct fallback behavior
    assert result == {:error, :service_unavailable}
  end
end
```

### Integration Testing with Brama

For integration testing:

```elixir
defmodule MyApp.IntegrationTest do
  use ExUnit.Case

  test "payment workflow handles service failures" do
    # Setup
    Brama.register("payment_api")
    Brama.register("notification_api")
    
    # Simulate failing payment API after 3 calls
    Brama.TestHelpers.setup_failing_after("payment_api", 3)
    
    # Run workflow multiple times
    results = Enum.map(1..5, fn _ -> MyApp.PaymentWorkflow.run() end)
    
    # Verify behavior
    assert Enum.count(results, &match?({:ok, _}, &1)) == 3
    assert Enum.count(results, &match?({:error, _}, &1)) == 2
  end
end
```

## Test Organization

Tests will be organized in common Elixir way.

