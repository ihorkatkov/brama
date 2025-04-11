# Changelog

## [1.1.0](https://github.com/ihorkatkov/brama/compare/v1.0.1...v1.1.0) (2025-04-11)


### Features

* update package description ([#14](https://github.com/ihorkatkov/brama/issues/14)) ([c06556d](https://github.com/ihorkatkov/brama/commit/c06556db68e1a92bcbef04eedf0136726961358b))

## [1.0.1](https://github.com/ihorkatkov/brama/compare/v1.0.0...v1.0.1) (2025-03-24)


### Bug Fixes

* connection manager flaky test ([#13](https://github.com/ihorkatkov/brama/issues/13)) ([99c8a22](https://github.com/ihorkatkov/brama/commit/99c8a2251be6e4790c90519e6570cbb7127639d4))
* docs ([#11](https://github.com/ihorkatkov/brama/issues/11)) ([abbeb2f](https://github.com/ihorkatkov/brama/commit/abbeb2fd296e975fa61d83f87d1359d11e18f5c1))

## 1.0.0 (2025-03-24)


### Features

* **.cursor/rules:** add Elixir development guidelines for Cursor IDE ([6f104ff](https://github.com/ihorkatkov/brama/commit/6f104ff0d35f92b72a519747452dde4d8bf61fd3))
* complete initial implementation of Brama circuit breaker library ([#5](https://github.com/ihorkatkov/brama/issues/5)) ([ff12e6a](https://github.com/ihorkatkov/brama/commit/ff12e6abd2606816f7e1fc0498e4f0083c6b1860))
* setup hex.pm release flow ([#8](https://github.com/ihorkatkov/brama/issues/8)) ([03a05ba](https://github.com/ihorkatkov/brama/commit/03a05babe46462aaff9bfe2e2de4670976c463f9))
* **specs:** create comprehensive library specifications for Brama circuit breaker with core architecture, API, circuit breaking, self-healing, notifications, failure isolation, configuration, testing strategy, and decorator pattern ([ad8b499](https://github.com/ihorkatkov/brama/commit/ad8b499956adee133fcc465225cc017a814ebf76))

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
