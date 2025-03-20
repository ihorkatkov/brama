import Config

config :brama,
  testing_mode: true,
  max_attempts: 1,
  cleanup_interval: 1_000,
  expiry: 100,
  inactive_threshold: 10_000
