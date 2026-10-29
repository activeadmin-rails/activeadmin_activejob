# frozen_string_literal: true

require "active_job"
require "activeadmin/jobs/version"
require "activeadmin/jobs/error"
require "activeadmin/jobs/adapters"
require "activeadmin/jobs/adapters/base"
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

      # Remove failed jobs when they are retried, instead of marking them retried.
      attr_accessor :remove_on_retry

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

      # Restore default configuration, e.g. between tests.
      def reset!
        @adapter = nil
        @adapter_name = nil
        self.scan_limit = 5_000
        self.remove_on_retry = false
      end
    end

    reset!
  end
end
