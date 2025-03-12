# Self-Healing Specification

## Overview

Self-healing is a critical feature of Brama that allows the system to automatically recover from failures without manual intervention. This document outlines how the self-healing mechanisms work, their configuration, and implementation details.

## Self-Healing Mechanisms

Brama implements several self-healing mechanisms:

1. **Expiry-Based Reset**
   - Open circuits automatically transition to half-open after a configurable expiry time
   - This allows the system to attempt recovery without manual intervention

2. **Automatic State Cleanup**
   - Inactive connections are periodically checked and potentially cleaned up
   - Prevents accumulation of stale connection data

3. **Progressive Recovery**
   - Half-open state allows a controlled test of dependency health
   - Prevents rapid cycle between open and closed states

## Expiry Configuration

The expiry time can be configured globally:

```elixir
config :brama,
  expiry: 60_000  # Default: 1 minute in milliseconds
```

Or per-connection:

```elixir
Brama.register("payment_api", expiry: 30_000)  # 30 seconds
```

## Cleanup Configuration

The cleanup process can be configured:

```elixir
config :brama,
  cleanup_interval: 10_000,     # How often to run cleanup (ms)
  inactive_threshold: 86_400_000  # Consider inactive after 24 hours
```

## Recovery Process

### Automatic Circuit Reset

1. Circuit opens due to failures reaching threshold
2. Time passes (expiry duration)
3. Circuit automatically transitions to half-open
4. Next request becomes a test request
5. If test succeeds, circuit closes
6. If test fails, circuit reopens with reset expiry timer

### Connection Cleanup

1. Periodic process runs at `cleanup_interval`
2. Identifies connections with no activity for `inactive_threshold`
3. Marks these connections for potential cleanup
4. After extended inactivity, removes connection data

## Implementation Details

### Time Tracking

- Each connection stores timestamps for key events:
  - Last failure time
  - Last success time
  - Open circuit time
  - Last activity time

### Expiry Calculation

- Current time is compared with `opened_at` timestamp
- If difference exceeds `expiry`, circuit transitions to half-open

### Cleanup Process

- Implemented as a separate process that wakes at configured intervals
- Uses a low-priority background job to prevent impact on performance
- Only reviews connections that have exceeded the inactivity threshold

## Manual Override

While self-healing is automatic, manual controls are available:

```elixir
# Force immediate reset to half-open
Brama.reset_expiry!(identifier)

# Set custom expiry for specific connection
Brama.set_expiry!(identifier, 120_000)  # 2 minutes

# Disable expiry (circuit stays open until manual intervention)
Brama.disable_expiry!(identifier)
```

## Progressive Backoff

For advanced self-healing, a progressive backoff mechanism is available:

```elixir
Brama.register("flaky_service", 
  expiry_strategy: :progressive,
  initial_expiry: 10_000,
  max_expiry: 300_000,
  backoff_factor: 2.0
)
```

This strategy:
- Starts with a short expiry time for first failure
- Increases expiry geometrically with repeated failures
- Caps at a maximum expiry time
- Resets to initial expiry after successful recovery 