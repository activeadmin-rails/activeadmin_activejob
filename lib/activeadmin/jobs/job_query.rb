# frozen_string_literal: true

require "kaminari"

module ActiveAdmin
  module Jobs
    class JobNotFound < Error; end

    # Lazy, immutable query over the jobs of one status, delegating to the
    # configured adapter. Implements the parts of the ActiveRecord::Relation
    # interface Active Admin's collection pipeline uses (count, page/per).
    #
    #   FailedJob.all.where(retried: true).offset(10).limit(5).to_a
    class JobQuery
      include Enumerable

      attr_reader :record_class, :filters, :offset_value, :limit_value

      def initialize(record_class, filters: {}, offset_value: 0, limit_value: nil, page_value: nil)
        @record_class = record_class
        @filters = filters.freeze
        @offset_value = offset_value
        @limit_value = limit_value
        @page_value = page_value
      end

      delegate :status, to: :record_class

      def where(**filters)
        spawn(filters: self.filters.merge(filters))
      end

      def offset(value)
        spawn(offset_value: value.to_i)
      end

      def limit(value)
        spawn(limit_value: value&.to_i)
      end

      # Kaminari-style pagination: +page(n).per(size)+ returns the page as a
      # Kaminari::PaginatableArray carrying the total count.
      def page(number = nil)
        spawn(page_value: [number.to_i, 1].max)
      end

      def per(size)
        size = size.to_i
        number = @page_value || 1
        records = offset((number - 1) * size).limit(size).to_a
        Kaminari.paginate_array(records, total_count: count).page(number).per(size)
      end

      def count
        @count ||= adapter.count_jobs(self)
      end
      alias size count

      def each(&)
        to_a.each(&)
      end

      def to_a
        @to_a ||= adapter.fetch_jobs(self)
      end

      # Whether filtering stopped at ActiveAdmin::Jobs.scan_limit entries, so
      # matching jobs beyond it are missing from #count and the results.
      def truncated?
        adapter.truncated?(self)
      end

      def find(id)
        adapter.find_job(id.to_s, self) or raise JobNotFound, "#{record_class.model_name.human} #{id} not found"
      end

      def find_by(id:)
        adapter.find_job(id.to_s, self)
      end

      # @return [Integer] the number of jobs retried
      def retry_all
        adapter.retry_all(self)
      end

      # @return [Integer] the number of jobs discarded
      def discard_all
        adapter.discard_all(self)
      end

      private

      def adapter
        ActiveAdmin::Jobs.adapter
      end

      def spawn(**changes)
        self.class.new(record_class, filters:, offset_value:, limit_value:, page_value: @page_value, **changes)
      end
    end
  end
end
