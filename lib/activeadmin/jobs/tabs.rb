# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # The tabs linking the jobs screens, as resque-web's: one per screen the
    # host application has registered and the user may read.
    class Tabs
      Tab = Struct.new(:id, :label, :path, :badge, :current, keyword_init: true)

      # @param view the Active Admin view context
      # @return [Array<Tab>]
      def self.for(view)
        new(view).to_a
      end

      def initialize(view)
        @view = view
        @namespace = view.active_admin_namespace
        @adapter = ActiveAdmin::Jobs.adapter
      end

      def to_a
        counts = @adapter.counts
        [
          overview_tab,
          resource_tab(Worker, counts[:workers]),
          resource_tab(FailedJob, counts[:failed], except: "stats"),
          (stats_tab if @adapter.supports?(:failure_stats)),
          (resource_tab(ScheduledJob) if @adapter.supports?(:scheduled_jobs))
        ].compact
      end

      private

      # Current on queued jobs too, which are reached from the overview's queues.
      def overview_tab
        page = Config.overview_page(@namespace)
        return unless page && @view.authorized?(ActiveAdmin::Auth::READ, page)

        queued = @namespace.resource_for(QueuedJob)
        Tab.new(id: "overview", label: I18n.t("active_admin.jobs.tabs.overview"),
                path: page.route_collection_path, current: [page, queued].compact.any? { |c| current?(c) })
      end

      def resource_tab(record_class, badge = nil, except: nil)
        config = readable(record_class) or return
        Tab.new(id: config.resource_name.route_key, label: config.plural_resource_label,
                path: config.route_collection_path, badge:,
                current: current?(config) && @view.action_name != except)
      end

      def stats_tab
        config = readable(FailedJob) or return
        path = @view.url_for(controller: "/#{config.controller.controller_path}", action: :stats, only_path: true)
        Tab.new(id: "failure_stats", label: I18n.t("active_admin.jobs.failed_jobs.stats"), path:,
                current: current?(config) && @view.action_name == "stats")
      end

      def readable(record_class)
        config = @namespace.resource_for(record_class)
        config if config && @view.authorized?(ActiveAdmin::Auth::READ, record_class)
      end

      def current?(config)
        @view.controller.is_a?(config.controller)
      end
    end
  end
end
