# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # A job that raised an exception and was recorded by the backend's failure store.
    class FailedJob < JobRecord
      attr_accessor :failed_at, :retried_at, :exception_class, :message, :backtrace, :worker, :entry

      def self.status
        :failed
      end

      def retried?
        retried_at.present?
      end
    end
  end
end
