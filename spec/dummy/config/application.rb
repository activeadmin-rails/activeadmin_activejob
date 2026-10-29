# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_record/railtie"
require "active_job/railtie"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)
require "resque"
require "activeadmin_activejob"

module Dummy
  # Dummy application for testing activeadmin_activejob
  class Application < Rails::Application
    config.load_defaults 8.0

    config.active_job.queue_adapter = :resque

    # dartsass-rails compiles SCSS → CSS into app/assets/builds/.
    # Ensure the asset pipeline (Propshaft or Sprockets) can find them.
    config.assets.paths << Rails.root.join("app/assets/builds")
  end
end
