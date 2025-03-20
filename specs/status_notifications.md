# Status Notifications Specification

## Overview

Brama provides a comprehensive event notification system that allows applications to react to connection status changes. This document outlines how the notification system works, the types of events generated, and how to subscribe to and handle these events.

## Event Types

Brama generates the following types of events:

| Event Type | Description |
|------------|-------------|
| `:state_change` | Connection state has changed (e.g., closed to open) |
| `:registration` | New connection registered with the system |
| `:failure` | Connection failure reported |
| `:success` | Connection success reported |
| `:expiry` | Circuit expiry time reached |
| `:cleanup` | Connection removed during cleanup |
| `:circuit_opened` | Circuit has been opened |
| `:circuit_closed` | Circuit has been closed |
| `:circuit_reset` | Circuit has been reset |
| `:connection_registered` | New connection registered |
| `:connection_unregistered` | Connection unregistered |
| `:circuit_half_opened` | Circuit has transitioned to half-open |
| `:connection_removed` | Connection has been removed |

## Event Data Structure

Each event contains detailed information about the connection and the event itself:

```elixir
%{
  event: :state_change,          # Type of event
  timestamp: 1630000000000,      # When the event occurred
  connection: "payment_api",     # Connection identifier
  scope: "payments",             # Connection scope
  data: %{                       # Event-specific data
    previous_state: :closed,
    new_state: :open,
    reason: "Threshold exceeded",
    failure_count: 10
  }
}
```

## Subscription API

### Global Subscription

Subscribe to all events for all connections:

```elixir
Brama.subscribe()
```

### Filtered Subscription

Subscribe to specific events or connections:

```elixir
# Subscribe to specific event types
Brama.subscribe(events: [:state_change, :failure])

# Subscribe to specific connection
Brama.subscribe(connection: "payment_api")

# Subscribe to scope
Brama.subscribe(scope: "payments")

# Combine filters
Brama.subscribe(
  events: [:state_change],
  connection: "payment_api"
)
```

### Unsubscribing

Unsubscribe using similar patterns:

```elixir
Brama.unsubscribe()  # Unsubscribe from all
Brama.unsubscribe(connection: "payment_api")  # Specific unsubscribe
```

## Event Handling

Events are delivered as standard Elixir messages to the subscribing process:

```elixir
def handle_info({:brama_event, event}, state) do
  # Handle the event
  Logger.info("Connection #{event.connection} changed to #{event.data.new_state}")
  {:noreply, state}
end
```

## Implementation Details

### Event Manager

- Implemented using Elixir's Registry or GenStage (depending on volume needs)
- Maintains a list of subscribers and their filter preferences
- Efficiently distributes events only to interested subscribers

### Performance Considerations

- Event generation is asynchronous to prevent blocking
- Subscription filters are applied at the source to minimize message volume
- High-volume systems can use batched event delivery

## Notification Behavior

Events have the following delivery guarantees:

- At-least-once delivery for critical state changes
- No guaranteed order of events
- No persistence of events (transient in-memory only)

## Integration with Monitoring Systems

For integration with external monitoring systems, Brama provides:

```elixir
# Custom event handler for integration
Brama.subscribe(handler: MyApp.MonitoringHandler)

# Telemetry integration
:telemetry.execute(
  [:brama, :connection, :state_change],
  %{duration: System.monotonic_time() - start_time},
  %{connection: "payment_api", previous_state: :closed, new_state: :open}
)
```

## Example Usage

```elixir
defmodule MyApp.ConnectionMonitor do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    # Subscribe to all state changes
    Brama.subscribe(events: [:state_change])
    {:ok, state}
  end

  def handle_info({:brama_event, event}, state) do
    if event.data.new_state == :open do
      # Alert on circuit open
      MyApp.Alerts.send("Circuit opened for #{event.connection}")
    end
    
    {:noreply, state}
  end
end
``` 