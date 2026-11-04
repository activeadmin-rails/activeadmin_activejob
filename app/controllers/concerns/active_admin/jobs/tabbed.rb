# frozen_string_literal: true

module ActiveAdmin
  module Jobs
    # Adds the jobs tabs (see Tabs) below the title bar: partials are looked up
    # in active_admin/jobs/navigation first, whose _title_bar adds them.
    module Tabbed
      extend ActiveSupport::Concern

      class_methods do
        private

        def local_prefixes
          [*super, "active_admin/jobs/navigation"]
        end
      end
    end
  end
end
