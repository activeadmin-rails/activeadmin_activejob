# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # Base controller for queues: sizes, and removing a queue with its jobs.
    class QueuesController < ActiveAdmin::ResourceController
      include ArrayCollection

      actions :index, :destroy

      rescue_from JobNotFound do
        redirect_to collection_path, alert: I18n.t("active_admin.jobs.queues.not_found")
      end

      def destroy
        authorize! ActiveAdmin::Auth::DESTROY, resource
        count = ActiveAdmin::Jobs.adapter.clear_queue(resource.name)
        redirect_to collection_path, notice: I18n.t("active_admin.jobs.queues.cleared", queue: resource.name, count:)
      end

      protected

      def scoped_collection
        resource_class.all
      end

      def find_resource
        resource_class.find_by(id: Param.decode(params[:id])) or raise JobNotFound
      end
    end
  end
end
