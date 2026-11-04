# frozen_string_literal: true

require "active_admin"

module ActiveAdmin
  module Jobs
    # Rails engine for activeadmin_activejob
    class Engine < ::Rails::Engine
      engine_name "activeadmin_activejob"

      ASSETS = %w[active_admin_jobs.css active_admin_jobs.js].freeze

      # Propshaft serves engine assets as they are; Sprockets must be told to
      # precompile them.
      initializer "activeadmin_activejob.precompile" do |app|
        app.config.assets.precompile += ASSETS if defined?(Sprockets::Railtie)
      end

      initializer "activeadmin_activejob.register_assets", after: :load_config_initializers do
        ActiveAdmin.application.register_stylesheet "active_admin_jobs.css", media: "screen"
        ActiveAdmin.application.register_javascript "active_admin_jobs.js"
      end
    end
  end
end
