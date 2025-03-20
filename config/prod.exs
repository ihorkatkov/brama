import Config

config :brama,
  max_attempts: 10,
  expiry: 60_000,
  cleanup_interval: 30_000,
  inactive_threshold: 86_400_000
