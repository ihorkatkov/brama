# Architecture Specification

## Overview

Brama's architecture is designed to provide robust connection management with minimal overhead. This document outlines the core components and their interactions within the library.

## Core Components

### Connection Registry

The central component that maintains the status of all registered connections. It:
- Stores connection identifiers and their current status
- Tracks failure counts and circuit states
- Provides an API for looking up connection statuses

### Circuit Breaker

This component implements the circuit breaking pattern:
- Monitors connection attempts and failures
- Implements configurable thresholds for state transitions
- Prevents calls to failing dependencies

### Status Manager

Responsible for:
- Updating connection status based on feedback
- Implementing the self-healing mechanism with expiry times
- Running the periodic cleanup process

### Event System

Enables applications to react to connection status changes:
- Publishes events when connection status changes
- Allows subscribers to be notified of specific or all connection changes
- Provides a decoupled way to react to availability changes
- Maintains a registry of subscribers with filtering preferences
- Supports subscribing to events by:
  - Event type (e.g., :state_change, :failure, :success)
  - Connection identifier
  - Connection type
  - Connection scope
- Allows unsubscribing from specific or all events
- Delivers events as standard messages to subscribing processes
- Implements filter-based delivery to minimize message volume

### Decorator

Provides a clean way to wrap functions with circuit breaking functionality:
- Implemented as Elixir macros for compile-time function wrapping
- Automatically checks circuit status before function execution
- Reports success or failure after function execution
- Handles circuit state appropriately on errors
- Minimizes boilerplate code for API consumers
- Works with both synchronous and asynchronous functions

## System Interaction Flow

1. Application registers connections with unique identifiers
2. Before making an external call, application checks connection status
3. After a call, application reports success or failure
4. Circuit breaker updates the status based on success/failure patterns
5. Subscribers are notified of any status changes

## Supervision Tree

Brama will use a supervision tree with the following structure:

```
BramaSupervisor
├── ConnectionRegistry (GenServer)
├── StatusManager (GenServer) 
└── EventManager (GenServer)
```

## State Management

Connection states will follow this pattern:
1. **Closed** - Normal operation, calls allowed
2. **Open** - Circuit broken, calls rejected without attempting
3. **Half-Open** - Test state, limited calls allowed to check recovery

## Error Handling

- Each component will handle its own internal errors
- Failures in one connection won't affect others
- The library will be defensive in handling invalid inputs
- All public functions will return tagged tuples (`{:ok, result}` or `{:error, reason}`)

## Performance Considerations

- Connection status lookups should be constant time operations
- Status updates should have minimal overhead
- The library should be able to handle thousands of connections
- Memory usage should scale linearly with the number of connections

## Extension Points

Brama's architecture will allow for extension in these areas:
- Custom connection types beyond the built-in ones
- Advanced status tracking mechanisms
- Integration with monitoring systems
- Custom notification handlers
- Custom event filtering mechanisms
- Custom decorator behavior for specialized use cases 