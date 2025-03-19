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

### State Manipulation

Tests can directly manipulate circuit state:

```elixir
# Force a connection into specific state
Brama.TestHelpers.set_state("payment_api", :open)

# Add failure count
Brama.TestHelpers.add_failures("payment_api", 5)
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