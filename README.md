# Brama

Brama is an Elixir library for reliable connection management with external dependencies. It provides robust tracking of connection statuses to APIs, services, databases, or any external system, with built-in circuit breaking to prevent cascading failures.

> This library is my first attempt at utilizing the ["stdlib" approach](https://ghuntley.com/stdlib/) for building software. This method involves creating comprehensive specifications before implementation, building a collection of Cursor rules to guide development, and treating AI as an autonomous agent rather than just a coding assistant. The whole library is going to be written by Cursor Agent with my supervision.

## Overview

When your application depends on external systems, knowing their availability status becomes critical. Brama serves as a gatekeeper (the name "Brama" means "gate" in several languages), monitoring your connections and protecting your application from external system failures.

## Features

- **Connection Monitoring**: Track status of both WebSocket and HTTP connections
- **Circuit Breaking**: Automatically prevent requests to failing systems after a threshold is reached
- **Self-Healing**: Connections automatically reset after a configurable expiry time
- **Status Notifications**: Subscribe to connection status change events
- **Failure Isolation**: Protect your application from cascading failures
- **Minimal Configuration**: Simple setup with reasonable defaults

## Overview

When your application depends on external systems, knowing their availability status becomes critical. Brama serves as a gatekeeper (the name "Brama" means "gate" in several languages), monitoring your connections and protecting your application from external system failures.

## Features

- **Connection Monitoring**: Track status of any connection
- **Circuit Breaking**: Automatically prevent requests to failing systems after a threshold is reached
- **Self-Healing**: Connections automatically reset after a configurable expiry time
- **Status Notifications**: Subscribe to connection status change events
- **Failure Isolation**: Protect your application from cascading failures
- **Minimal Configuration**: Simple setup with reasonable defaults

## Installation

Add Brama to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:brama, "~> 0.1.0"}
  ]
end
```
## Circuit Breaking Mechanism

Brama implements circuit breaking for any connection with these behaviors:

1. Each connection type is tracked separately
2. After a configurable number of failed attempts (default: 10), the circuit opens
3. When open, all requests are rejected without attempting the external call
4. After a configurable time period (default: 1 minute), the circuit closes again
5. Connections have immediate status updates

## Configuration Options

```elixir
config :brama,
  max_attempts: 10,           # Attempts before circuit opens
  cleanup_interval: 10_000,   # Status check interval in ms
  expiry: 60_000              # Circuit open duration in ms
```

## Advanced Usage

You can extend Brama for specific needs:

- Create custom monitoring modules for specialized protocols
- Implement advanced health checking logic
- Build metrics collection around connection statuses
- Integrate with monitoring and alerting systems

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

Brama is released under the MIT License.