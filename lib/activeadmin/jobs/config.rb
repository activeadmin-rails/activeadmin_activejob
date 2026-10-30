# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # Active Admin resource configuration for the job resources, applied by the
    # host application:
    #
    #   ActiveAdmin.configure_resource ActiveAdmin::Jobs::FailedJob, as: "FailedJob" do |config|
    #     ActiveAdmin::Jobs::Config.failed_jobs(config)
    #   end
    module Config
      module_function

      # Path to the index of another job resource in +namespace+, or nil when
      # the host application has not registered it.
      def path_for(namespace, resource_class, params = {})
        namespace.resource_for(resource_class)&.route_collection_path({}, params)
      end

      def queued_jobs(config)
        read_only_jobs(config, title: proc { I18n.t("active_admin.jobs.queued_jobs.title", queue: current_queue) })
        config.add_sidebar_section "Queues", only: :index, partial: "queues_sidebar"
        config.batch_actions = true
        config.remove_batch_action :destroy
        config.add_batch_action :discard, proc { I18n.t("active_admin.jobs.discard") },
                                confirm: proc { I18n.t("active_admin.jobs.queued_jobs.batch_discard_confirmation") },
                                if: proc { authorized?(ActiveAdmin::Auth::DESTROY, active_admin_config.resource_class) }
      end

      def queues(config)
        read_only_jobs(config)
        config.batch_actions = false
      end

      def workers(config)
        read_only_jobs(config)
        config.batch_actions = false
      end

      # The overview page needs no configuration yet; kept for symmetry.
      def overview(_config); end

      # Index options are set once: the first index presenter is the default.
      def read_only_jobs(config, **index_options)
        config.filters = false
        config.current_filters = false
        config.set_page_options :index, download_links: false, **index_options
      end

      def failed_jobs(config)
        config.filters = false
        config.current_filters = false
        config.set_page_options :index, download_links: false

        config.add_member_route :retry, method: :post
        config.add_collection_route :retry_all, method: :post
        config.add_collection_route :clear_all, method: :delete
        config.add_collection_route :clear_retried, method: :delete

        failed_job_batch_actions(config)
        failed_job_action_items(config)
      end

      def failed_job_batch_actions(config)
        config.batch_actions = true
        config.remove_batch_action :destroy
        config.add_batch_action :retry, proc { I18n.t("active_admin.jobs.retry") },
                                priority: 1,
                                confirm: proc { I18n.t("active_admin.jobs.failed_jobs.batch_retry_confirmation") },
                                if: proc { authorized?(:retry, active_admin_config.resource_class) }
        config.add_batch_action :discard, proc { I18n.t("active_admin.jobs.discard") },
                                priority: 2,
                                confirm: proc { I18n.t("active_admin.jobs.failed_jobs.batch_discard_confirmation") },
                                if: proc { authorized?(ActiveAdmin::Auth::DESTROY, active_admin_config.resource_class) }
      end

      def failed_job_action_items(config)
        config.add_action_item :retry, only: :show do
          if authorized?(:retry, resource)
            link_to I18n.t("active_admin.jobs.retry"), url_for(action: :retry, id: resource.id), method: :post
          end
        end

        collection_action_item(config, :retry_all, :post, :retry)
        collection_action_item(config, :clear_retried, :delete, ActiveAdmin::Auth::DESTROY,
                               visible: proc { ActiveAdmin::Jobs::Config.show_retried?(collection) })
        collection_action_item(config, :clear_all, :delete, ActiveAdmin::Auth::DESTROY)
      end

      # Whether to show retried state: when marking jobs retried, or when the
      # page has jobs marked retried by another tool (e.g. resque-web).
      def show_retried?(jobs)
        !ActiveAdmin::Jobs.remove_on_retry || jobs.any?(&:retried?)
      end

      # A confirmed link to a collection action, shown when the collection is not empty.
      def collection_action_item(config, name, method, permission, visible: nil)
        config.add_action_item name, only: :index do
          if collection.total_count.positive? && authorized?(permission, active_admin_config.resource_class) &&
             (visible.nil? || instance_exec(&visible))
            scope = "active_admin.jobs.#{controller_name}"
            confirm = I18n.t("#{name}_confirmation", scope:, count: collection.total_count)
            link_to I18n.t(name, scope:), url_for(action: name), method:, data: { confirm: }
          end
        end
      end
    end
  end
end
