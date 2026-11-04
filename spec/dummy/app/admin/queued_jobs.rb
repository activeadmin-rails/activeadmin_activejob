# frozen_string_literal: true

ActiveAdmin.configure_resource ActiveAdmin::Jobs::QueuedJob, as: "QueuedJob" do |config|
  ActiveAdmin::Jobs::Config.queued_jobs(config)
  config.menu_item_options = false # reached through the jobs tabs
end
