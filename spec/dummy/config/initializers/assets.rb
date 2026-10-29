# frozen_string_literal: true

# Sprockets-specific asset configuration (skipped when using Propshaft)
if defined?(Sprockets)
  Rails.application.config.assets.version = "1.0"
  Rails.application.config.assets.precompile += %w[active_admin.js active_admin.css]
end
