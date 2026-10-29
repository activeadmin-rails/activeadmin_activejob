# frozen_string_literal: true

# Tests flush this database, so default to one an app is unlikely to use.
Resque.redis = ENV.fetch("REDIS_URL", "redis://localhost:6379/15")
