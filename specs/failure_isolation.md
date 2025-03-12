# Failure Isolation Specification

## Overview

Failure isolation is a key resilience pattern in Brama that prevents failures in one external dependency from affecting the entire system. This document outlines how Brama implements failure isolation, its benefits, and usage patterns.

## Failure Isolation Principles

Brama follows these core principles for failure isolation:

1. **Independence** - Each connection is tracked independently
2. **Containment** - Failures in one system don't impact others
3. **Fast Rejection** - Failing connections are rejected quickly without consuming resources
4. **Degraded Functionality** - Applications can continue with reduced functionality

## Isolation Mechanisms

### Connection Isolation

- Each connection is tracked separately
- Failure of one connection doesn't affect others
- Different services can have different circuit thresholds and expiry times

### Scope-Based Isolation

- Connections can be grouped by logical scope (e.g., "payments", "inventory")
- Enables business-domain isolation
- Status querying and reporting by scope

## Implementation

### Independent Circuit State

Each connection maintains its own circuit state:

```elixir
# Different services have independent circuits
Brama.register("payment_api")
Brama.register("shipping_api")

# Failure in payment_api doesn't affect shipping_api
Brama.failure("payment_api")
Brama.available?("shipping_api")  # Still true
```

### Failure Handling

Applications use Brama for graceful degradation:

```elixir
defmodule UserService do
  use Brama.Decorator

  def get_user_data(user_id) do
    profile = get_user_profile(user_id)
    case get_payment_history(user_id) do
      {:ok, history} ->
        # ...
      {:error, _reason} ->
        # ...
    end
  end
  
  # Circuit breaker automatically handles checking availability,
  # reporting success/failure, and providing fallback
  @circuit_breaker identifier: "payment_api"
  defp get_payment_history(user_id) do
    # Fetch data from an external API
  end
  
  defp get_user_profile(user_id) do
    # Profile fetching logic
  end
end
```

## Group Management

For logical service groups:

```elixir
# Register a service group
Brama.register_group("payment_services", [
  "payment_api", 
  "invoice_service", 
  "tax_calculator"
])

# Check entire group
Brama.group_available?("payment_services")

# Report to entire group
Brama.group_failure("payment_services")
```

## Isolation Benefits

The failure isolation provided by Brama offers these benefits:

1. **Improved Stability** - Prevents cascading failures
2. **Resource Conservation** - Fast-fails requests to unavailable services
3. **Partial Availability** - System continues operating with reduced functionality
4. **Targeted Recovery** - Services can recover independently

## Failure Isolation Strategy Recommendations

1. Identify critical vs. non-critical dependencies
2. Use shorter thresholds for critical services
3. Always provide degraded functionality where possible
4. Use scopes to group related services
5. Consider fallbacks for critical functionality 