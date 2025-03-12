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

### Type-Based Isolation

- Connections can be grouped by type (e.g., HTTP, DB, Redis)
- Different types have isolated failure tracking
- Enables different policies for different connection types

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
def get_user_data(user_id) do
  profile = get_user_profile(user_id)
  
  # Only attempt if connection is available
  payment_history = 
    if Brama.available?("payment_api") do
      case get_payment_history(user_id) do
        {:ok, history} ->
          Brama.success("payment_api")
          history
        {:error, reason} ->
          Brama.failure("payment_api")
          []
      end
    else
      # Return empty if circuit is open
      []
    end
    
  %{profile: profile, payments: payment_history}
end
```

## Bulk Operations

For systems that need to check multiple connections:

```elixir
# Check multiple connections at once
statuses = Brama.bulk_available?(["payment_api", "shipping_api", "inventory_api"])

# Report multiple results at once
Brama.bulk_report([
  {:success, "payment_api"},
  {:failure, "shipping_api"},
  {:success, "inventory_api"}
])
```

## Fallback Mechanisms

Brama supports registering fallbacks for unavailable services:

```elixir
Brama.register("primary_payment_api", fallback: "secondary_payment_api")

# Use the fallback mechanism
def process_payment(payment) do
  cond do
    Brama.available?("primary_payment_api") ->
      call_primary_api(payment)
      
    Brama.available?("secondary_payment_api") ->
      call_secondary_api(payment)
      
    true ->
      {:error, :all_payment_services_unavailable}
  end
end
```

## Cascading Dependency Isolation

For complex dependencies:

```elixir
# Register dependencies
Brama.register("shipping_calculator", 
  depends_on: ["inventory_api", "location_service"])

# Automatically unavailable if dependencies are unavailable
Brama.available?("shipping_calculator")  # false if any dependency is unavailable
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