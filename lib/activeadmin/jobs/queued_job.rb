# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # A job waiting in a queue. Queries need a queue:
    #
    #   QueuedJob.all.where(queue: "default")
    class QueuedJob < JobRecord
      def self.status
        :pending
      end
    end
  end
end
