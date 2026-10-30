# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # Base controller for workers (read only), working workers first.
    class WorkersController < ActiveAdmin::ResourceController
      include ArrayCollection

      actions :index, :show

      rescue_from JobNotFound do
        redirect_to collection_path, alert: I18n.t("active_admin.jobs.workers.not_found")
      end

      protected

      def scoped_collection
        resource_class.all.sort_by { |worker| [worker.working? ? 0 : 1, worker.id] }
      end

      def find_resource
        resource_class.find_by(id: Param.decode(params[:id])) or raise JobNotFound
      end
    end
  end
end
