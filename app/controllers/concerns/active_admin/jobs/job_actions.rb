# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # Actions shared by job resource controllers: finding jobs by id, removing
    # them singly or in batches, and reporting jobs that have gone meanwhile.
    module JobActions
      extend ActiveSupport::Concern

      included do
        helper_method :jobs_filter_query, :jobs_truncated?

        rescue_from JobNotFound do
          redirect_to jobs_collection_path, alert: I18n.t("active_admin.jobs.not_found")
        end
      end

      def destroy
        authorize! ActiveAdmin::Auth::DESTROY, resource
        if ActiveAdmin::Jobs.adapter.discard_job(resource)
          redirect_to jobs_collection_path, notice: I18n.t("active_admin.jobs.discarded", count: 1)
        else
          redirect_to jobs_collection_path, alert: I18n.t("active_admin.jobs.not_found")
        end
      end

      protected

      def scoped_collection
        resource_class.all
      end

      def find_resource
        scoped_collection.find(Param.decode(params[:id]))
      end

      # The index to return to after an action, keeping any filters.
      def jobs_collection_path
        collection_path(**jobs_filter_query)
      end

      # Query parameters selecting the current filters, if any.
      def jobs_filter_query
        {}
      end

      # Whether the filtered collection stopped at ActiveAdmin::Jobs.scan_limit.
      def jobs_truncated?
        return @jobs_truncated if defined?(@jobs_truncated)

        @jobs_truncated = scoped_collection.truncated?
      end

      def batch_action_discard(ids, _inputs)
        count = batch_jobs(ids, ActiveAdmin::Auth::DESTROY).count { |job| ActiveAdmin::Jobs.adapter.discard_job(job) }
        redirect_after_batch("active_admin.jobs.discarded", count, ids)
      end

      private

      # Jobs still present, authorized for +action+, last position first.
      def batch_jobs(ids, action)
        jobs = Array(ids).filter_map { |id| scoped_collection.find_by(id:) }
        jobs.each { |job| authorize! action, job }
        jobs.sort_by { |job| -job.position }
      end

      def redirect_after_batch(message, count, ids)
        missing = Array(ids).size - count
        flash[:alert] = I18n.t("active_admin.jobs.missing", count: missing) if missing.positive?
        redirect_to jobs_collection_path, notice: I18n.t(message, count:)
      end
    end
  end
end
