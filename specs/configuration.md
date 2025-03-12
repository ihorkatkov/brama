# Configuration Specification

## Overview

Brama's configuration system is designed to be flexible while providing reasonable defaults. This document outlines the configuration options, their defaults, and how to customize them for specific needs.

## Global Configuration

Brama is configured in your application's config files:

```elixir
# In config/config.exs
config :brama,
  # Circuit breaker settings
  max_attempts: 10,           # Attempts before circuit opens (default: 10)
  expiry: 60_000,             # Circuit open duration in ms (default: 60,000)
  
  # Cleanup settings
  cleanup_interval: 10_000,   # Status check interval in ms (default: 10,000)
  inactive_threshold: 86_400_000,  # Time before cleanup in ms (default: 24 hours)
  
  # Operation settings
  telemetry_prefix: [:brama], # Telemetry event prefix (default: [:brama])
  default_type: :general,     # Default connection type (default: :general)
  
  # Testing settings
  testing_mode: false         # Testing mode (default: false)
```

## Per-Connection Configuration

Each connection can override global settings during registration:

```elixir
Brama.register("payment_api", 
  max_attempts: 5,            # Override max attempts for this connection
  expiry: 30_000,             # Override expiry time for this connection
  type: :http,                # Specify connection type
  scope: "payment_services",  # Logical grouping
  metadata: %{                # Additional information
    url: "https://payments.example.com/api",
    priority: :critical
  }
)
```

## Environment-Specific Configurations

Brama supports different configurations per environment:

```elixir
# In config/dev.exs
config :brama,
  max_attempts: 3,            # Lower threshold in development
  expiry: 10_000              # Faster recovery in development

# In config/test.exs
config :brama,
  testing_mode: true,         # Enable testing mode
  max_attempts: 1,            # Immediate circuit opening for tests
  cleanup_interval: 1_000     # Faster cleanup for tests

# In config/prod.exs
config :brama,
  max_attempts: 10,           # Standard threshold in production
  expiry: 60_000,             # Standard recovery in production
  cleanup_interval: 30_000    # Less frequent cleanup in production
```

## Configuration Precedence

Configuration values are determined in this order of precedence:
1. Per-connection settings (highest priority)
2. Runtime configuration updates
3. Environment-specific global settings
4. Default values (lowest priority)

## Runtime Configuration

Brama allows updating configuration at runtime:

```elixir
# Update global settings
Brama.configure(max_attempts: 15, expiry: 120_000)

# Update specific connection
Brama.configure("payment_api", max_attempts: 5, expiry: 30_000)
```

## Configuration Options Reference

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `max_attempts` | Integer | 10 | Number of failures before circuit opens |
| `expiry` | Integer | 60_000 | Time in ms before open circuit transitions to half-open |
| `cleanup_interval` | Integer | 10_000 | Time in ms between cleanup checks |
| `inactive_threshold` | Integer | 86_400_000 | Time in ms before connection considered inactive |
| `default_type` | Atom | `:general` | Default connection type if none specified |
| `telemetry_prefix` | List | `[:brama]` | Prefix for telemetry events |
| `testing_mode` | Boolean | `false` | Enable testing features |

## Advanced Configuration

### Progressive Backoff

```elixir
Brama.register("flaky_service", 
  expiry_strategy: :progressive,
  initial_expiry: 10_000,
  max_expiry: 300_000,
  backoff_factor: 2.0
)
```

### Custom Connection Types

```elixir
# Register custom connection types with default settings
config :brama, :connection_types, %{
  http: [max_attempts: 10, expiry: 60_000],
  database: [max_attempts: 5, expiry: 30_000],
  cache: [max_attempts: 15, expiry: 5_000]
}
```

### Telemetry Configuration

```elixir
config :brama, :telemetry,
  enabled: true,
  prefix: [:my_app, :brama],
  events: [:circuit_open, :circuit_close, :failure, :success]
```

## Configuration at Application Start

Initialize Brama with dynamic configuration at application start:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    # Initial configuration based on environment
    Brama.configure(
      max_attempts: Application.get_env(:my_app, :circuit_max_attempts, 10),
      expiry: Application.get_env(:my_app, :circuit_expiry, 60_000)
    )
    
    # ... supervisor setup
  end
end
```

## Configuration Validation

All configuration values are validated at startup and when changed:
- Numeric values must be positive integers
- Timeout values have reasonable minimums
- Invalid configurations raise helpful error messages 