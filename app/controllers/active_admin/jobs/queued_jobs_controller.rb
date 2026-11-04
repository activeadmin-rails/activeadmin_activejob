# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # Base controller for the jobs waiting in a queue, selected with the
    # +queue+ parameter (defaulting to the first queue), and for clearing a queue.
    class QueuedJobsController < ActiveAdmin::ResourceController
      include Tabbed
      include LivePoll
      include JobActions

      actions :index, :show, :destroy

      helper_method :current_queue, :queues

      # Removes the queue and its jobs, as resque-web does, returning to the
      # jobs overview when it is registered.
      def clear
        authorize! ActiveAdmin::Auth::DESTROY, resource_class
        name = params[:queue]
        path = Config.overview_path(active_admin_namespace) || collection_path
        unless queues.any? { |queue| queue.name == name }
          return redirect_to path, alert: I18n.t("active_admin.jobs.queued_jobs.queue_not_found")
        end

        count = ActiveAdmin::Jobs.adapter.clear_queue(name)
        redirect_to path, notice: I18n.t("active_admin.jobs.queued_jobs.cleared", queue: name, count:)
      end

      protected

      def scoped_collection
        resource_class.all.where(queue: current_queue)
      end

      def find_resource
        resource_class.all.find(Param.decode(params[:id]))
      end

      def jobs_filter_query
        { queue: current_queue }
      end

      # From the +queue+ parameter, else the job's or selected jobs' queue
      # (batch actions do not keep query parameters), else the first queue.
      def current_queue
        @current_queue ||= params[:queue].presence ||
                           queue_from_id(params[:id] || Array(params[:collection_selection]).first) ||
                           queues.first&.name
      end

      def queues
        @queues ||= ActiveAdmin::Jobs.adapter.queues
      end

      private

      def queue_from_id(id)
        Param.decode(id).split("-", 3)[2] if id
      end
    end
  end
end
