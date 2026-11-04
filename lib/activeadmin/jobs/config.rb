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

      # The jobs overview page registered in +namespace+, if any.
      def overview_page(namespace)
        namespace.resources.detect do |config|
          config.is_a?(ActiveAdmin::Page) && config.controller <= OverviewController
        end
      end

      def overview_path(namespace)
        overview_page(namespace)&.route_collection_path
      end

      def queued_jobs(config)
        read_only_jobs(config, title: proc { I18n.t("active_admin.jobs.queued_jobs.title", queue: current_queue) })
        config.add_sidebar_section "Queues", only: :index, partial: "queues_sidebar"
        config.add_collection_route :clear, method: :delete
        live_poll_action_item(config)
        collection_action_item(config, :clear, :delete, ActiveAdmin::Auth::DESTROY)
        config.batch_actions = true
        config.remove_batch_action :destroy
        config.add_batch_action :discard, proc { I18n.t("active_admin.jobs.discard") },
                                confirm: proc { I18n.t("active_admin.jobs.queued_jobs.batch_discard_confirmation") },
                                if: proc { authorized?(ActiveAdmin::Auth::DESTROY, active_admin_config.resource_class) }
      end

      def scheduled_jobs(config)
        read_only_jobs(config)
        config.add_member_route :enqueue_now, method: :post
        config.add_collection_route :clear_all, method: :delete
        scheduled_job_batch_actions(config)

        config.add_action_item :enqueue_now, only: :show do
          if authorized?(:enqueue_now, resource)
            link_to I18n.t("active_admin.jobs.enqueue_now"), url_for(action: :enqueue_now, id: resource.to_param),
                    method: :post
          end
        end
        collection_action_item(config, :clear_all, :delete, ActiveAdmin::Auth::DESTROY)
      end

      def scheduled_job_batch_actions(config)
        config.batch_actions = true
        config.remove_batch_action :destroy
        config.add_batch_action :enqueue_now, proc { I18n.t("active_admin.jobs.enqueue_now") },
                                priority: 1,
                                confirm: proc { I18n.t("active_admin.jobs.scheduled_jobs.batch_enqueue_confirmation") },
                                if: proc { authorized?(:enqueue_now, active_admin_config.resource_class) }
        config.add_batch_action :discard, proc { I18n.t("active_admin.jobs.discard") },
                                priority: 2,
                                confirm: proc { I18n.t("active_admin.jobs.scheduled_jobs.batch_discard_confirmation") },
                                if: proc { authorized?(ActiveAdmin::Auth::DESTROY, active_admin_config.resource_class) }
      end

      def workers(config)
        read_only_jobs(config)
        config.batch_actions = false
        live_poll_action_item(config)
      end

      def overview(config)
        live_poll_action_item(config)
      end

      # Toggles live polling (LivePoll) of the index.
      def live_poll_action_item(config)
        config.add_action_item :live_poll, only: :index do
          query = request.query_parameters.symbolize_keys
          if live_poll?
            link_to I18n.t("active_admin.jobs.live_poll.stop"), url_for(query.except(:poll))
          else
            link_to I18n.t("active_admin.jobs.live_poll.start"), url_for(query.merge(poll: 1))
          end
        end
      end

      # Index options are set once: the first index presenter is the default.
      def read_only_jobs(config, **index_options)
        config.filters = false
        config.current_filters = false
        config.set_page_options :index, download_links: false, **index_options
      end

      # Filter choices for failure age, in hours.
      FAILURE_AGES = [1, 3, 6, 12, 24, 72, 168, 336, 672].freeze

      def failed_jobs(config)
        config.filters = false
        config.current_filters = false
        config.set_page_options :index, download_links: false

        config.add_member_route :retry, method: :post
        config.add_collection_route :retry_all, method: :post
        config.add_collection_route :clear_all, method: :delete
        config.add_collection_route :clear_retried, method: :delete
        config.add_collection_route :stats, method: :get
        config.add_sidebar_section :filters, only: :index, partial: "filters_sidebar"

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
            link_to I18n.t("active_admin.jobs.retry"), url_for(action: :retry, id: resource.to_param), method: :post
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

      # Label for a failure age in hours, e.g. "3 hours" or "7 days".
      def age_label(hours)
        if hours < 24
          I18n.t("active_admin.jobs.hours", count: hours)
        else
          I18n.t("active_admin.jobs.days", count: hours / 24)
        end
      end

      # A confirmed link to a collection action on the current (filtered)
      # collection, shown when the collection is not empty.
      def collection_action_item(config, name, method, permission, visible: nil)
        config.add_action_item name, only: :index do
          if collection.total_count.positive? && authorized?(permission, active_admin_config.resource_class) &&
             (visible.nil? || instance_exec(&visible))
            link_to I18n.t(name, scope: "active_admin.jobs.#{controller_name}"),
                    url_for(action: name, **jobs_filter_query), method:,
                                                                data: { confirm: ActiveAdmin::Jobs::Config.confirmation(self, name, collection.total_count) }
          end
        end
      end

      # Confirmation for a collection action, warning when the count shown
      # stopped at the scan limit.
      def confirmation(view, name, count)
        scope = "active_admin.jobs.#{view.controller_name}"
        # The filter query (e.g. +queue+) can be interpolated too.
        confirm = I18n.t("#{name}_confirmation", scope:, count:, **view.jobs_filter_query)
        return confirm unless view.jobs_truncated?

        limit = ActiveSupport::NumberHelper.number_to_delimited(ActiveAdmin::Jobs.scan_limit)
        "#{confirm} #{I18n.t("active_admin.jobs.truncated_confirmation", limit:)}"
      end
    end
  end
end
