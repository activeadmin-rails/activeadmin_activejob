# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # Base controller for failed jobs. Host applications subclass it in their
    # Active Admin namespace, e.g.
    #
    #   class Admin::FailedJobsController < ActiveAdmin::Jobs::FailedJobsController; end
    #
    # and configure the resource with ActiveAdmin::Jobs::Config.failed_jobs.
    class FailedJobsController < ActiveAdmin::ResourceController
      actions :index, :show, :destroy

      rescue_from JobNotFound do
        redirect_to collection_path, alert: I18n.t("active_admin.jobs.not_found")
      end

      def retry
        authorize! :retry, resource
        if ActiveAdmin::Jobs.adapter.retry_job(resource)
          redirect_to collection_path, notice: I18n.t("active_admin.jobs.retried", count: 1)
        else
          redirect_to collection_path, alert: I18n.t("active_admin.jobs.not_found")
        end
      end

      def destroy
        authorize! ActiveAdmin::Auth::DESTROY, resource
        if ActiveAdmin::Jobs.adapter.discard_job(resource)
          redirect_to collection_path, notice: I18n.t("active_admin.jobs.discarded", count: 1)
        else
          redirect_to collection_path, alert: I18n.t("active_admin.jobs.not_found")
        end
      end

      def retry_all
        authorize! :retry, resource_class
        count = scoped_collection.retry_all
        redirect_to collection_path, notice: I18n.t("active_admin.jobs.retried", count:)
      end

      def clear_all
        authorize! ActiveAdmin::Auth::DESTROY, resource_class
        count = scoped_collection.discard_all
        redirect_to collection_path, notice: I18n.t("active_admin.jobs.discarded", count:)
      end

      def clear_retried
        authorize! ActiveAdmin::Auth::DESTROY, resource_class
        count = scoped_collection.where(retried: true).discard_all
        redirect_to collection_path, notice: I18n.t("active_admin.jobs.discarded", count:)
      end

      protected

      def scoped_collection
        resource_class.all
      end

      def find_resource
        scoped_collection.find(params[:id])
      end

      def batch_action_retry(ids, _inputs)
        count = batch_jobs(ids, :retry).count { |job| ActiveAdmin::Jobs.adapter.retry_job(job) }
        redirect_to collection_path, notice: I18n.t("active_admin.jobs.retried", count:)
      end

      def batch_action_discard(ids, _inputs)
        count = batch_jobs(ids, ActiveAdmin::Auth::DESTROY).count { |job| ActiveAdmin::Jobs.adapter.discard_job(job) }
        redirect_to collection_path, notice: I18n.t("active_admin.jobs.discarded", count:)
      end

      private

      # Jobs still present, authorized for +action+, last position first.
      def batch_jobs(ids, action)
        jobs = Array(ids).filter_map { |id| scoped_collection.find_by(id:) }
        jobs.each { |job| authorize! action, job }
        jobs.sort_by { |job| -job.position }
      end
    end
  end
end
