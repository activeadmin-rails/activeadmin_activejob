# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # A worker process registered with the backend, and the job it is running.
    class Worker
      include ActiveModel::Model

      attr_accessor :id, :host, :pid, :queues, :started_at, :heartbeat_at, :processed, :failed,
                    :job_class, :job_id, :job_queue, :arguments, :run_at

      class << self
        def all
          ActiveAdmin::Jobs.adapter.workers
        end

        def find_by(conditions)
          id = conditions.to_h.symbolize_keys[:id]
          all.detect { |worker| worker.id == id }
        end
      end

      def working?
        run_at.present?
      end

      def state
        working? ? :working : :idle
      end

      def persisted?
        true
      end

      def to_param
        Param.encode(id)
      end

      def display_name
        id
      end
    end
  end
end
