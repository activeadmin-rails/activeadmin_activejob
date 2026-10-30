# frozen_string_literal: true

require "active_model"

module ActiveAdmin
  module Jobs
    # A job read from a queue backend, presented to Active Admin as an
    # ActiveModel record. Subclasses (e.g. FailedJob) select the job status and
    # act as the Active Admin resource class.
    class JobRecord
      include ActiveModel::Model

      # Identity and backend bookkeeping. +raw+ is the entry exactly as stored,
      # used to verify the entry is unchanged before acting on it; +entry+ is it
      # decoded, with filtered parameters masked, for display.
      attr_accessor :id, :position, :raw, :entry

      # The job, unwrapped from the backend's payload.
      attr_accessor :job_class, :job_id, :queue_name, :arguments, :executions, :enqueued_at, :scheduled_at

      class << self
        # The job status selected by this class, e.g. :failed.
        def status
          raise NotImplementedError, "#{name} must define .status"
        end

        def all
          JobQuery.new(self)
        end

        delegate :find, to: :all

        # Used by Active Admin breadcrumbs.
        def find_by(conditions)
          all.find_by(**conditions.to_h.symbolize_keys)
        end
      end

      def persisted?
        true
      end

      def to_param
        Param.encode(id)
      end

      def display_name
        [job_class, job_id].compact.join(" ")
      end
    end
  end
end
