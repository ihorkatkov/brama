import Config

config :brama,
  max_attempts: 10,
  expiry: 60_000,
  cleanup_interval: 10_000,
  inactive_threshold: 86_400_000

import_config "#{config_env()}.exs"
