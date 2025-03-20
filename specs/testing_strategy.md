# Testing Strategy Specification

## Overview

This document outlines the testing strategy for the Brama library, focusing on unit testing, integration testing, and providing helper functions for testing applications that use Brama.

## Testing Levels

### Unit Testing

All components of Brama will have comprehensive unit tests:

Each unit test will focus on a single component in isolation, using mocks or stubs for dependencies.

### Integration Testing

Integration tests will verify interactions between components:

- Connection registration to event notification flow
- Circuit state transitions under various conditions
- Cleanup and expiry interactions

## Test Helpers Module

Brama provides a dedicated `Brama.TestHelpers` module that simplifies testing of applications that use Brama. This module includes functions for:

- Directly manipulating circuit states
- Simulating failures and recoveries
- Working with connection scopes

### Available Helper Functions

#### Setting Circuit State

```elixir
@spec set_state(String.t(), atom(), Keyword.t()) :: :ok | {:error, term()}
```

Directly sets the state of a circuit to `:closed`, `:open`, or `:half_open`. Options include:

- `scope`: Optional scope to target a specific connection scope
- `reason`: Optional reason for the state change (default: "Test setup")

The implementation uses the appropriate Brama functions internally:
- For `:open` state, uses `Brama.open_circuit!`
- For `:closed` state, uses `Brama.close_circuit!`
- For `:half_open` state, opens the circuit first and then uses a specialized internal function

```elixir
# Force a connection into open state
Brama.TestHelpers.set_state("payment_api", :open)

# Force a connection in a specific scope into closed state
Brama.TestHelpers.set_state("payment_api", :closed, scope: "external_vendors")

# Set a connection to half-open state
Brama.TestHelpers.set_state("payment_api", :half_open)
```

#### Simulating Failures

```elixir
@spec add_failures(String.t(), non_neg_integer(), Keyword.t()) :: :ok | {:error, term()}
```

Adds a specific number of consecutive failures to a connection. Options include:

- `scope`: Optional scope to target a specific connection scope
- Other options passed to underlying Brama functions

```elixir
# Add 5 failures to a connection
Brama.TestHelpers.add_failures("payment_api", 5)

# Add failures to a scoped connection
Brama.TestHelpers.add_failures("payment_api", 3, scope: "external_vendors")
```

```elixir
@spec simulate_failures(String.t(), non_neg_integer(), Keyword.t()) :: :ok | {:error, term()}
```

Alias for `add_failures/3` that simulates a service temporarily failing.

```elixir
# Simulate 5 failures for a service
Brama.TestHelpers.simulate_failures("payment_api", 5)
```

#### Simulating Recovery

```elixir
@spec simulate_recovery(String.t(), Keyword.t()) :: :ok | {:error, term()}
```

Simulates a service recovering by reporting a success. Options include:

- `scope`: Optional scope to target a specific connection scope
- Other options passed to underlying Brama functions

```elixir
# Simulate service recovery
Brama.TestHelpers.simulate_recovery("payment_api")

# Simulate recovery for a scoped connection
Brama.TestHelpers.simulate_recovery("payment_api", scope: "external_vendors")
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

  test "circuit opens after multiple failures" do
    # Simulate failures
    add_failures("payment_api", 10)
    
    # Assert circuit state
    assert {:ok, %{state: :open}} = Brama.status("payment_api")
  end

  test "circuit transitions to half-open after recovery period" do
    # Setup: open the circuit
    set_state("payment_api", :open)
    
    # Simulate time passing (in a real test, you might use mocking for time)
    # Then transition to half-open
    set_state("payment_api", :half_open)
    
    # Assert correct state
    assert {:ok, %{state: :half_open}} = Brama.status("payment_api")
  end

  test "circuit closes after successful recovery" do
    # Setup: set to half-open
    set_state("payment_api", :half_open)
    
    # Simulate recovery
    simulate_recovery("payment_api")
    
    # Assert circuit closed
    assert {:ok, %{state: :closed}} = Brama.status("payment_api")
  end
end
```