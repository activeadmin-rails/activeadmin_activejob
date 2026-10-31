# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    module Adapters
      # Contract implemented by each queue backend. Method names follow
      # mission_control-jobs (MissionControl::Jobs::Adapter) so that a bridge to
      # its adapters remains straightforward.
      #
      # Optional features are advertised with #supports?; the UI only offers
      # screens and actions for supported features.
      class Base
        FEATURES = %i[scheduled_jobs recurring_tasks workers failure_stats queue_pausing].freeze

        def supports?(_feature)
          false
        end

        # Queues

        # @return [Array<ActiveAdmin::Jobs::Queue>]
        def queues
          not_implemented :queues
        end

        # @return [Integer] the number of jobs removed
        def clear_queue(_name)
          not_implemented :clear_queue
        end

        # Jobs, selected by a query with status (:pending, :failed, :scheduled),
        # filters, offset and limit.

        def count_jobs(_query)
          not_implemented :count_jobs
        end

        def fetch_jobs(_query)
          not_implemented :fetch_jobs
        end

        def find_job(_id, _query)
          not_implemented :find_job
        end

        def retry_job(_job)
          not_implemented :retry_job
        end

        def discard_job(_job)
          not_implemented :discard_job
        end

        def retry_all(_query)
          not_implemented :retry_all
        end

        def discard_all(_query)
          not_implemented :discard_all
        end

        # Whether the query's results were cut short by ActiveAdmin::Jobs.scan_limit.
        def truncated?(_query)
          false
        end

        # Optional features

        def enqueue_now(_job)
          not_implemented :enqueue_now
        end

        # @return [Array<ActiveAdmin::Jobs::Worker>]
        def workers
          not_implemented :workers
        end

        # @return [Hash] backend statistics for display, e.g. :pending, :processed, :failed
        def stats
          not_implemented :stats
        end

        private

        def not_implemented(method_name)
          raise NotImplementedError, "#{self.class.name} must implement ##{method_name}"
        end
      end
    end
  end
end
