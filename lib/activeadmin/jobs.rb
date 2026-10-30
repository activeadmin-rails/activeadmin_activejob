# frozen_string_literal: true

require "active_job"
require "active_support/parameter_filter"
require "activeadmin/jobs/version"
require "activeadmin/jobs/error"
require "activeadmin/jobs/adapters"
require "activeadmin/jobs/adapters/base"
require "activeadmin/jobs/param"
require "activeadmin/jobs/job_record"
require "activeadmin/jobs/failed_job"
require "activeadmin/jobs/queued_job"
require "activeadmin/jobs/scheduled_job"
require "activeadmin/jobs/queue"
require "activeadmin/jobs/worker"
require "activeadmin/jobs/job_query"
require "activeadmin/jobs/config"
require "activeadmin/jobs/engine"

module ActiveAdmin
  # Monitor and retry ActiveJob background jobs from Active Admin.
  #
  # ActiveJob has no API for listing or acting on enqueued or failed jobs, so
  # all queries go through a backend adapter (see ActiveAdmin::Jobs::Adapters::Base).
  module Jobs
    class << self
      # Name of the backend adapter, e.g. :resque. Defaults to the name of
      # ActiveJob::Base.queue_adapter.
      attr_writer :adapter_name

      # Maximum number of entries read when a filter can only be applied in
      # memory (e.g. failed jobs by class or exception).
      attr_accessor :scan_limit

      # Remove failed jobs when they are retried (default), instead of marking
      # them retried as resque-web does.
      attr_accessor :remove_on_retry

      # Parameter names masked in displayed job arguments. Defaults to
      # Rails.application.config.filter_parameters.
      attr_writer :filter_parameters

      def configure
        yield self
      end

      def adapter_name
        @adapter_name || ActiveJob.adapter_name(ActiveJob::Base.queue_adapter).underscore.to_sym
      end

      # The adapter instance for the configured backend.
      def adapter
        @adapter ||= Adapters.lookup(adapter_name)
      end

      def filter_parameters
        @filter_parameters || (defined?(Rails) && Rails.application&.config&.filter_parameters) || []
      end

      # Masks filter_parameters in job arguments (or any nested Hash/Array).
      def filter_arguments(value)
        return value unless value.is_a?(Hash) || value.is_a?(Array)

        ActiveSupport::ParameterFilter.new(filter_parameters).filter("value" => value)["value"]
      end

      # Restore default configuration, e.g. between tests.
      def reset!
        @adapter = nil
        @adapter_name = nil
        @filter_parameters = nil
        self.scan_limit = 5_000
        self.remove_on_retry = true
      end
    end

    reset!

    Adapters.register(:resque) do
      require "activeadmin/jobs/adapters/resque"
      Adapters::Resque.new
    end
  end
end
