import Config

config :brama,
  max_attempts: 3,
  expiry: 10_000,
  cleanup_interval: 10_000,
  inactive_threshold: 86_400_000
