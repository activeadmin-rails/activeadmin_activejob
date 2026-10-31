# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # Matches failed jobs against JobQuery filters in memory, for backends
    # that cannot filter where they store failures.
    module FailureFilter
      MATCHERS = {
        retried: ->(job, value) { job.retried? == value },
        job_class: ->(job, value) { job.job_class == value },
        exception_class: ->(job, value) { job.exception_class == value },
        queue_name: ->(job, value) { job.queue_name == value },
        failed_after: ->(job, time) { job.failed_at.present? && job.failed_at >= time },
        failed_before: ->(job, time) { job.failed_at.present? && job.failed_at < time },
        # A Regexp, matched against the entry with filtered parameters masked
        # so that it cannot reveal them.
        pattern: ->(job, regexp) { regexp.match?(job.entry.to_json) }
      }.freeze

      module_function

      def match?(job, filters)
        filters.all? do |name, value|
          matcher = MATCHERS.fetch(name) { raise ArgumentError, "Unsupported failed job filter: #{name.inspect}" }
          matcher.call(job, value)
        end
      end
    end
  end
end
