# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # Base controller for failed jobs. Host applications subclass it in their
    # Active Admin namespace, e.g.
    #
    #   class Admin::FailedJobsController < ActiveAdmin::Jobs::FailedJobsController; end
    #
    # and configure the resource with ActiveAdmin::Jobs::Config.failed_jobs.
    #
    # The index is filtered by the +filter+ parameters (see FILTERS). Filtering
    # reads at most ActiveAdmin::Jobs.scan_limit failures, newest first.
    class FailedJobsController < ActiveAdmin::ResourceController
      include JobActions

      FILTERS = %w[job_class exception_class queue_name newer_than older_than pattern].freeze
      # Seconds a filter pattern may take to match one job.
      PATTERN_TIMEOUT = 1

      actions :index, :show, :destroy

      helper_method :filter_params, :failure_stats

      rescue_from RegexpError do |error|
        redirect_to collection_path,
                    alert: I18n.t("active_admin.jobs.failed_jobs.invalid_pattern", error: error.message)
      end

      def index
        notify_truncated
        super
      end

      def retry
        authorize! :retry, resource
        if ActiveAdmin::Jobs.adapter.retry_job(resource)
          redirect_to jobs_collection_path, notice: I18n.t("active_admin.jobs.retried", count: 1)
        else
          redirect_to jobs_collection_path, alert: I18n.t("active_admin.jobs.not_found")
        end
      end

      def retry_all
        authorize! :retry, resource_class
        count = scoped_collection.retry_all
        redirect_to jobs_collection_path, notice: I18n.t("active_admin.jobs.retried", count:)
      end

      def clear_all
        authorize! ActiveAdmin::Auth::DESTROY, resource_class
        count = scoped_collection.discard_all
        redirect_to jobs_collection_path, notice: I18n.t("active_admin.jobs.discarded", count:)
      end

      def clear_retried
        authorize! ActiveAdmin::Auth::DESTROY, resource_class
        count = scoped_collection.where(retried: true).discard_all
        redirect_to jobs_collection_path, notice: I18n.t("active_admin.jobs.discarded", count:)
      end

      def stats
        authorize! ActiveAdmin::Auth::READ, resource_class
        @page_title = I18n.t("active_admin.jobs.failed_jobs.stats")
      end

      protected

      def scoped_collection
        resource_class.all.where(**failure_filters)
      end

      def jobs_filter_query
        filter_params.empty? ? {} : { filter: filter_params }
      end

      def failure_stats
        @failure_stats ||= FailureStats.new(resource_class.all)
      end

      # The current +filter+ parameters, without blanks.
      def filter_params
        @filter_params ||= begin
          filter = params[:filter]
          filter.respond_to?(:permit) ? filter.permit(*FILTERS).to_h.compact_blank : {}
        end
      end

      def batch_action_retry(ids, _inputs)
        count = batch_jobs(ids, :retry).count { |job| ActiveAdmin::Jobs.adapter.retry_job(job) }
        redirect_after_batch("active_admin.jobs.retried", count, ids)
      end

      private

      def failure_filters
        filters = filter_params.symbolize_keys
        filters.slice(:job_class, :exception_class, :queue_name).merge(
          failed_after: hours_ago(filters[:newer_than]),
          failed_before: hours_ago(filters[:older_than]),
          pattern: (Regexp.new(filters[:pattern], timeout: PATTERN_TIMEOUT) if filters[:pattern])
        ).compact
      end

      def hours_ago(hours)
        hours = Float(hours, exception: false) if hours
        hours.hours.ago if hours&.positive?
      end

      def notify_truncated
        return unless jobs_truncated?

        limit = ActiveSupport::NumberHelper.number_to_delimited(ActiveAdmin::Jobs.scan_limit)
        flash.now[:notice] = I18n.t("active_admin.jobs.failed_jobs.truncated", limit:)
      end
    end
  end
end
