# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # Base controller for scheduled jobs (resque-scheduler's delayed jobs).
    class ScheduledJobsController < ActiveAdmin::ResourceController
      include JobActions

      actions :index, :show, :destroy

      def enqueue_now
        authorize! :enqueue_now, resource
        if ActiveAdmin::Jobs.adapter.enqueue_now(resource)
          redirect_to collection_path, notice: I18n.t("active_admin.jobs.enqueued", count: 1)
        else
          redirect_to collection_path, alert: I18n.t("active_admin.jobs.not_found")
        end
      end

      def clear_all
        authorize! ActiveAdmin::Auth::DESTROY, resource_class
        count = scoped_collection.discard_all
        redirect_to collection_path, notice: I18n.t("active_admin.jobs.discarded", count:)
      end

      protected

      def batch_action_enqueue_now(ids, _inputs)
        count = batch_jobs(ids, :enqueue_now).count { |job| ActiveAdmin::Jobs.adapter.enqueue_now(job) }
        redirect_after_batch("active_admin.jobs.enqueued", count, ids)
      end
    end
  end
end
