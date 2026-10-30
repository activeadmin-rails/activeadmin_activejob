# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # A job scheduled to be enqueued at a later time (e.g. +perform_later+ with +wait:+).
    class ScheduledJob < JobRecord
      def self.status
        :scheduled
      end
    end
  end
end
