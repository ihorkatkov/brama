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

## State Management

Connection states will follow this pattern:
1. **Closed** - Normal operation, calls allowed
2. **Open** - Circuit broken, calls rejected without attempting
3. **Half-Open** - Test state, limited calls allowed to check recovery

### Circuit Breaker Terminology Note

The circuit breaker pattern borrows terminology from electrical engineering:

- **Closed Circuit**: In electrical terms, a closed circuit allows current to flow through it. Similarly, in our circuit breaker, the "Closed" state allows calls to flow through to the external service. This is the normal, healthy operational state.

- **Open Circuit**: An electrical open circuit has a break that prevents current from flowing. In our circuit breaker, the "Open" state prevents calls from reaching the failing service, protecting the system from cascading failures.

- **Half-Open Circuit**: This transitional state allows a limited number of test calls to determine if the external service has recovered. Based on the success or failure of these test calls, the circuit will either return to "Closed" (if successful) or remain "Open" (if still failing).

This naming convention, while potentially counterintuitive at first, maintains consistency with industry-standard circuit breaker implementations.

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
- Advanced status tracking mechanisms
- Telemetry integration
- Custom notification handlers
- Custom event filtering mechanisms
- Custom decorator behavior for specialized use cases 