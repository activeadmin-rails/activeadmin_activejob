# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # Refreshes the index every ActiveAdmin::Jobs.poll_interval seconds while
    # the +poll+ parameter is set, as resque-web's "Live Poll" does. See
    # Config.live_poll_action_item for the toggle.
    module LivePoll
      extend ActiveSupport::Concern

      included do
        helper_method :live_poll?
      end

      protected

      def live_poll?
        params[:poll].present? && action_name == "index"
      end
    end
  end
end
