# Changelog

## 1.0.0 (2025-03-24)


### Features

* **.cursor/rules:** add Elixir development guidelines for Cursor IDE ([6f104ff](https://github.com/ihorkatkov/brama/commit/6f104ff0d35f92b72a519747452dde4d8bf61fd3))
* complete initial implementation of Brama circuit breaker library ([#5](https://github.com/ihorkatkov/brama/issues/5)) ([ff12e6a](https://github.com/ihorkatkov/brama/commit/ff12e6abd2606816f7e1fc0498e4f0083c6b1860))
* setup hex.pm release flow ([#8](https://github.com/ihorkatkov/brama/issues/8)) ([03a05ba](https://github.com/ihorkatkov/brama/commit/03a05babe46462aaff9bfe2e2de4670976c463f9))
* **specs:** create comprehensive library specifications for Brama circuit breaker with core architecture, API, circuit breaking, self-healing, notifications, failure isolation, configuration, testing strategy, and decorator pattern ([ad8b499](https://github.com/ihorkatkov/brama/commit/ad8b499956adee133fcc465225cc017a814ebf76))


### Documentation

* **readme:** add explanation of stdlib approach and development method ([976f6e4](https://github.com/ihorkatkov/brama/commit/976f6e4c3136b08e9ca271ef27a3acb7886895cd))
* **specs:** clarify circuit breaker terminology and update architecture details ([d5c13d1](https://github.com/ihorkatkov/brama/commit/d5c13d18def09dfc10990ae5a1869e2ab5042d30))


### Code Refactoring

* **specs:** simplify API and streamline documentation for MVP ([00655e7](https://github.com/ihorkatkov/brama/commit/00655e723e67e5e97acf2d23bc818bea0cc5718e))

## 1.0.0 (2023-03-21)

### Features

* Initial stable release
* Connection monitoring with circuit breaking functionality
* Self-healing mechanism for circuit breakers
* Status change notifications
* Decorator API for function-level circuit breaking
* Flexible expiry strategies (fixed and progressive backoff)
* Telemetry integration
* Comprehensive documentation and testing
