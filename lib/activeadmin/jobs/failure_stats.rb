# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # Counts of failed jobs by job class and by exception, in total and within
    # recent periods, as in resque-cleaner. Reads at most
    # ActiveAdmin::Jobs.scan_limit failures, newest first.
    class FailureStats
      # Periods, in hours before now.
      PERIODS = [1, 3, 24, 72, 168].freeze

      # +name+ is nil for the totals row.
      Row = Struct.new(:name, :total, :counts) do
        def add(failed_at, cutoffs)
          self.total += 1
          cutoffs.each { |hours, cutoff| counts[hours] += 1 if failed_at && failed_at >= cutoff }
        end
      end

      attr_reader :total

      def initialize(query, now: Time.current)
        limit = ActiveAdmin::Jobs.scan_limit
        @truncated = limit.present? && query.count > limit
        @by_class = {}
        @by_exception = {}
        @total = new_row(nil)
        cutoffs = PERIODS.index_with { |hours| now - hours.hours }
        (limit ? query.limit(limit) : query).each { |job| add(job, cutoffs) }
      end

      # Rows by job class, most failures first.
      def by_class
        sorted(@by_class)
      end

      # Rows by exception class, most failures first.
      def by_exception
        sorted(@by_exception)
      end

      def truncated?
        @truncated
      end

      private

      def add(job, cutoffs)
        rows = [
          @by_class[job.job_class] ||= new_row(job.job_class),
          @by_exception[job.exception_class] ||= new_row(job.exception_class),
          @total
        ]
        rows.each { |row| row.add(job.failed_at, cutoffs) }
      end

      def new_row(name)
        Row.new(name, 0, Hash.new(0))
      end

      def sorted(rows)
        rows.values.sort_by { |row| [-row.total, row.name.to_s] }
      end
    end
  end
end
